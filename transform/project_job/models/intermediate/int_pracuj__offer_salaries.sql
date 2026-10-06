-- models/intermediate/int_pracuj__offer_salaries.sql
-- Przygotowanie rekordów wynagrodzeń z pracuj.pl do załadowania do silver.offer_salaries
-- Materialized jako ephemeral — SQL (CTE) dla modelu innego modelu (nie trzyma danych w locie)


{{
    config(
        materialized = 'ephemeral'
    )
}}


WITH base AS (
    SELECT
        raw_id,
        source_offer_id,
		bronze_file_id,
		offer_date,
        salary_info
    FROM {{ ref('stg_pracuj') }}
    WHERE salary_info IS NOT NULL
	and salary_info::text not like '%"N/A"%'
),

parsed AS (
    SELECT
        raw_id,
		bronze_file_id,
		offer_date,
        source_offer_id,

        -- element 0: kwota, np. "110,00 zł" lub "8 000 – 12 000 zł"
        NULLIF(TRIM(salary_info->>0), '')   AS raw_amount,

        -- element 1: metadane, np. "netto (+ VAT) / godz. | kontrakt B2B"
        NULLIF(TRIM(salary_info->>1), '')   AS raw_meta

    FROM base
),

extracted AS (
    SELECT
        bronze_file_id,
		offer_date,
        source_offer_id,

        -- salary_min: pierwsza liczba przed " – "
        replace(REGEXP_REPLACE(
            SPLIT_PART(raw_amount, ' – ', 1),
            '[^0-9,]', '', 'g'
        ),',', '.')::NUMERIC                          AS salary_min,

        -- salary_max: jeśli jest widełka to druga część, inaczej = min
        CASE
            WHEN raw_amount LIKE '% – %'
            THEN replace(REGEXP_REPLACE(
                    SPLIT_PART(raw_amount, ' – ', 2),
                    '[^0-9,]', '', 'g'
                 ),',', '.')::NUMERIC
            ELSE replace(REGEXP_REPLACE(
                    SPLIT_PART(raw_amount, ' – ', 1),
                    '[^0-9,]', '', 'g'
                 ),',', '.')::NUMERIC
        END                                 AS salary_max,

        -- currency: PLN zawsze dla pracuj
        'PLN'                               AS currency,

        -- period: godzina lub miesiąc
        CASE
            WHEN lower(raw_meta) ILIKE '%godz%'    THEN 'HOURLY'
			WHEN lower(raw_meta) ILIKE '%hr.%'    THEN 'HOURLY'
			WHEN lower(raw_meta) ILIKE '%mth%'    THEN 'MONTHLY'
            WHEN lower(raw_meta) ILIKE '%mies%'    THEN 'MONTHLY'
            ELSE NULL
        END                                 AS period,

        -- salary_type: netto lub brutto
        CASE
            WHEN lower(raw_meta) ILIKE '%net%'   THEN 'NETTO'
            WHEN lower(raw_meta) ILIKE '%brutto%'  THEN 'BRUTTO'
			WHEN lower(raw_meta) ILIKE '%gross%'  THEN 'BRUTTO'
            ELSE NULL
        END                                 AS salary_type,

        -- contract_type: po " | "
        CASE
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%b2b%' THEN 'B2B'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%contra%employm%' THEN 'UoP'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%umow%pracę%' THEN 'UoP'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%zlecenie%' THEN 'Umowa zlecenie'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%mandate%' THEN 'Umowa zlecenie'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%zastępstwo%' THEN 'Umowa na zastępstwo'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%replacem%' THEN 'Umowa na zastępstwo'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%substitution%' THEN 'Umowa na zastępstwo'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%staż%' THEN 'Umowa o staż'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%praktyki%' THEN 'Umowa o staż'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%internsh%' THEN 'Umowa o staż'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%dzieło%' THEN 'Umowa o dzieło'
			WHEN NULLIF(TRIM(SPLIT_PART(lower(raw_meta), '| ', 2)), '') ILIKE '%dzielo%' THEN 'Umowa o dzieło'
		ELSE NULLIF(TRIM(SPLIT_PART(raw_meta, '| ', 2)), '') END AS contract_type

    FROM parsed
    WHERE raw_amount IS NOT NULL
),

normalized AS
(
SELECT
  bronze_file_id
, offer_date
, source_offer_id
, contract_type 
, salary_min
, salary_max
, currency
, CASE 
	WHEN salary_min < 1000 AND period = 'HOURLY' THEN 'HOURLY' 
	WHEN period = 'MONTHLY' THEN 'MONTHLY'
	ELSE NULL END as period
, salary_type
FROM extracted
)

SELECT bronze_file_id, offer_date, source_offer_id, contract_type ,salary_min, salary_max, currency, period, salary_type FROM normalized 
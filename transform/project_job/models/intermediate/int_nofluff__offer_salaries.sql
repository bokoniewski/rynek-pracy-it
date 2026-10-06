-- models/intermediate/int_nofluff__offer_salaries.sql
-- Parsowanie salary_info z nofluffjobs.com → wiersze per typ umowy
-- Każdy element listy to osobny string z kwotą, walutą, typem umowy i okresem

{{ config(materialized='ephemeral') }}

WITH base AS (
    SELECT
        raw_id,
        bronze_file_id,
        offer_date,
        source_offer_id,
        jsonb_array_elements_text(salary_info) AS salary_item
    FROM {{ ref('stg_nofluff') }}
    WHERE salary_info IS NOT NULL
      AND salary_info::text NOT LIKE '%N/A%'
),

-- Odrzuć rekordy bez kwoty (Bezpłatny staż, N/A itp.)
-- Jeśli nie zaczyna się od cyfry → brak kwoty → pomijamy
filtered AS (
    SELECT *
    FROM base
    WHERE salary_item ~ '^\d'
),

parsed AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,

        -- salary_min: pierwsza liczba przed " – " jeśli widełki
        -- lub część przed " PLN" jeśli jedna kwota
        -- SPLIT_PART(..., ' PLN', 1) zatrzymuje się przed walutą
        -- dzięki temu B2B, VAT i inne śmieci z cyframi są ignorowane
        NULLIF(
            REPLACE(
                REGEXP_REPLACE(
                    CASE
                        WHEN salary_item LIKE '% – %'
                        THEN SPLIT_PART(salary_item, ' – ', 1)
                        ELSE SPLIT_PART(salary_item, ' PLN', 1)
                    END,
                    '[^0-9,]', '', 'g'
                ), ',', '.'
            ), ''
        )::NUMERIC                                              AS salary_min_raw,

        -- salary_max: jeśli są widełki → część między " – " a " PLN"
        -- jeśli jedna kwota → = min
        NULLIF(
            REPLACE(
                REGEXP_REPLACE(
                    CASE
                        WHEN salary_item LIKE '% – %'
                        THEN SPLIT_PART(
                                SPLIT_PART(salary_item, ' – ', 2),
                                ' PLN', 1
                             )
                        ELSE SPLIT_PART(salary_item, ' PLN', 1)
                    END,
                    '[^0-9,]', '', 'g'
                ), ',', '.'
            ), ''
        )::NUMERIC                                              AS salary_max_raw,

        -- currency: PLN / EUR / USD
        CASE
            WHEN salary_item ILIKE '%EUR%' THEN 'EUR'
            WHEN salary_item ILIKE '%USD%' THEN 'USD'
            ELSE 'PLN'
        END                                                     AS currency,

        -- period: miesięcznie lub godzinowo
        CASE
            WHEN salary_item ILIKE '%godz%'   THEN 'HOURLY'
            WHEN salary_item ILIKE '%hr.%'    THEN 'HOURLY'
            WHEN salary_item ILIKE '%mies%'   THEN 'MONTHLY'
            WHEN salary_item ILIKE '%mth%'    THEN 'MONTHLY'
            WHEN salary_item ILIKE '%dzien%'  THEN 'DAILY'
            WHEN salary_item ILIKE '%rocz%'   THEN 'ANNUALLY'
            ELSE NULL
        END                                                     AS period_raw,

        -- contract_type: wyciągamy z nawiasów na końcu stringa
        -- np. "(B2B)" "(UoP)" "(UZ)"
        NULLIF(TRIM(
            REGEXP_REPLACE(
                COALESCE(
                    SUBSTRING(salary_item FROM '\(([^)]+)\)[^(]*$'),
                    ''
                ),
                '\s+', ' ', 'g'
            )
        ), '')                                                  AS raw_contract,

        -- salary_type: B2B zawsze NETTO, reszta BRUTTO
        CASE
            WHEN salary_item ILIKE '%B2B%'   THEN 'NETTO'
            WHEN salary_item ILIKE '%VAT%'   THEN 'NETTO'
            WHEN salary_item ILIKE '%netto%' THEN 'NETTO'
            ELSE 'BRUTTO'
        END                                                     AS salary_type

    FROM filtered
),

-- Korekcja period i salary_max
corrected AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,
        raw_contract,
        salary_min_raw                                          AS salary_min,
        COALESCE(salary_max_raw, salary_min_raw)                AS salary_max,
        currency,
        salary_type,

        CASE
            WHEN period_raw = 'HOURLY' AND salary_min_raw < 1000  		THEN 'HOURLY'
            WHEN period_raw = 'MONTHLY' AND salary_min_raw >= 1000      THEN 'MONTHLY'
            WHEN period_raw = 'DAILY'                             		THEN 'DAILY'
            WHEN period_raw = 'ANNUALLY' AND salary_min_raw >= 30000    THEN 'ANNUALLY'
            ELSE NULL
        END

    FROM parsed
    WHERE salary_min_raw IS NOT NULL
      AND salary_min_raw > 0
),

-- Normalizacja contract_type
normalized AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,
        salary_min,
        salary_max,
        currency,
        period,
        salary_type,

        CASE
            WHEN raw_contract ILIKE '%B2B%'                 THEN 'B2B'
            WHEN raw_contract ILIKE '%UoP%'
              OR raw_contract ILIKE '%umow%pracę%'
              OR raw_contract ILIKE '%employm%'             THEN 'UoP'
            WHEN raw_contract ILIKE '%UZ%'
              OR raw_contract ILIKE '%zlecen%'              THEN 'Umowa zlecenie'
            WHEN raw_contract ILIKE '%zastępstwo%'          THEN 'Umowa na zastępstwo'
            WHEN raw_contract ILIKE '%staż%'
              OR raw_contract ILIKE '%praktyki%'
              OR raw_contract ILIKE '%internsh%'            THEN 'Umowa o staż'
			WHEN raw_contract ILIKE '%specific%'            
			  OR raw_contract ILIKE '%uod%'					THEN 'Umowa o dzieło'
            ELSE raw_contract
        END                                                 AS contract_type

    FROM corrected
)

SELECT
    bronze_file_id,
    offer_date,
    source_offer_id,
    contract_type,
    salary_min,
    salary_max,
    currency,
    period,
    salary_type
FROM normalized

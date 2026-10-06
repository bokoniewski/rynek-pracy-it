-- models/intermediate/int_protocol__offer_salaries.sql
-- Parsowanie salary_info z theprotocol.it → wiersze per typ umowy
-- Format: {"salary": "9000 - 12 000 zł netto (+ VAT) / mies.", "contract_type": "kontrakt B2B (pełny etat)"}
-- Odrzucamy: "brak widełek", "salary not specified"

{{ config(materialized='ephemeral') }}

WITH base AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,
        jsonb_array_elements(salary_info) AS salary_item
    FROM {{ ref('stg_protocol') }}
    WHERE salary_info IS NOT NULL
      AND salary_info::text NOT ILIKE '%N/A%'
),

-- Wyciągnij pola ze słownika i odrzuć rekordy bez kwoty
extracted AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(salary_item->>'salary')        AS raw_salary,
        TRIM(salary_item->>'contract_type') AS raw_contract
    FROM base
    -- Odrzuć rekordy bez kwoty — musi zaczynać się od cyfry
    WHERE salary_item->>'salary' ~ '^\d'
),

parsed AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,
        raw_salary,
        raw_contract,

        -- salary_min: pierwsza liczba przed " - "
        NULLIF(
            REPLACE(
                REGEXP_REPLACE(
                    CASE
                        WHEN raw_salary ~ '\d\s+-\s+\d'
                        THEN SPLIT_PART(raw_salary, ' - ', 1)
                        ELSE SPLIT_PART(raw_salary, 'zł', 1)
                    END,
                    '[^0-9.]', '', 'g'
                ), ',', '.'
            ), ''
        )::NUMERIC                          AS salary_min_raw,

        -- salary_max: druga liczba przed "zł" lub = min gdy jedna kwota
        NULLIF(
            REPLACE(
                REGEXP_REPLACE(
                    CASE
                        WHEN raw_salary ~ '\d\s+-\s+\d'
                        THEN SPLIT_PART(
                                SPLIT_PART(raw_salary, ' - ', 2),
                                'zł', 1
                             )
                        ELSE SPLIT_PART(raw_salary, 'zł', 1)
                    END,
                    '[^0-9.]', '', 'g'
                ), ',', '.'
            ), ''
        )::NUMERIC                          AS salary_max_raw,

        -- currency: zawsze PLN dla theprotocol.it
        'PLN'                               AS currency,

        -- salary_type: B2B/VAT → NETTO, reszta → BRUTTO
        CASE
            WHEN raw_salary ILIKE '%netto%'  THEN 'NETTO'
            WHEN raw_salary ILIKE '%net%'    THEN 'NETTO'
            WHEN raw_salary ILIKE '%VAT%'    THEN 'NETTO'
            WHEN raw_salary ILIKE '%brutto%' THEN 'BRUTTO'
            WHEN raw_contract ILIKE '%B2B%'  THEN 'NETTO'
            ELSE 'BRUTTO'
        END                                 AS salary_type,

        -- period: godz/hr → HOURLY, mies/mth → MONTHLY
        -- korekcja: < 500 to na pewno HOURLY
        CASE
            WHEN raw_salary ILIKE '%godz%'   THEN 'HOURLY'
            WHEN raw_salary ILIKE '%hr.%'    THEN 'HOURLY'
            WHEN raw_salary ILIKE '%mies%'   THEN 'MONTHLY'
            WHEN raw_salary ILIKE '%mth%'    THEN 'MONTHLY'
            ELSE NULL
        END                                 AS period_raw

    FROM extracted
),

-- Korekcja period i salary_max
corrected AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,
        raw_contract,
        salary_min_raw                          AS salary_min,
        COALESCE(salary_max_raw, salary_min_raw) AS salary_max,
        currency,
        salary_type,

        CASE
            --WHEN salary_min_raw < 1000   							THEN 'HOURLY'
            WHEN period_raw = 'HOURLY' and salary_min_raw < 1000  	THEN 'HOURLY'
            WHEN period_raw = 'MONTHLY' 							THEN 'MONTHLY'
            ELSE NULL
        END                                     AS period

    FROM parsed
    WHERE salary_min_raw IS NOT NULL 
	and salary_min_raw > 0
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
            WHEN raw_contract ILIKE '%B2B%'         THEN 'B2B'
            WHEN raw_contract ILIKE '%umow%pracę%'
              OR raw_contract ILIKE '%employm%'      THEN 'UoP'
            WHEN raw_contract ILIKE '%zlecen%'
              OR raw_contract ILIKE '%mandate%'      THEN 'Umowa zlecenie'
            WHEN raw_contract ILIKE '%zastępstwo%'
              OR raw_contract ILIKE '%replacem%'     THEN 'Umowa na zastępstwo'
			WHEN raw_contract ILIKE '%dzieło%'
              OR raw_contract ILIKE '%dzielo%'     THEN 'Umowa o dzieło'
            WHEN raw_contract ILIKE '%staż%'
              OR raw_contract ILIKE '%praktyki%'
              OR raw_contract ILIKE '%internsh%'     THEN 'Umowa o staż'
            ELSE raw_contract
        END                                         AS contract_type

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
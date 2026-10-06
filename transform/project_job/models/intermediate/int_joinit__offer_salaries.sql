-- models/intermediate/int_joinit__offer_salaries.sql
-- Parsowanie salary z justjoin.it → wiersze per typ umowy
-- Obsługiwane formaty:
--   "20 000 - 21 500 PLNGross per month - Permanent"   → widełki
--   "90 PLNNet per hour - B2B"                         → jedna kwota
--   "15 089.23 - 17 665.44 PLNGross per month - Permanent" → z kropką dziesiętną

{{ config(materialized='ephemeral') }}

WITH base AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,
        jsonb_array_elements_text(salary) AS salary_item
    FROM {{ ref('stg_joinit') }}
    WHERE salary IS NOT NULL
      AND salary::text NOT ILIKE '%N/A%'
),

-- Odrzuć rekordy bez kwoty — musi zaczynać się od cyfry
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
        salary_item,

        -- czy są widełki: cyfra - cyfra przed PLN
        (salary_item ~ '\d\s+-\s+\d')                          AS has_range,

        -- salary_min
        -- widełki: pierwsza część przed " - "
        -- jedna kwota: część przed PLN
        NULLIF(
            REPLACE(
                REGEXP_REPLACE(
                    CASE
                        WHEN salary_item ~ '\d\s+-\s+\d'
                        THEN SPLIT_PART(salary_item, ' - ', 1)
                        ELSE SPLIT_PART(salary_item, 'PLN', 1)
                    END,
                    '[^0-9.]', '', 'g'
                ), ',', '.'
            ), ''
        )::NUMERIC                                              AS salary_min_raw,

        -- salary_max
        -- widełki: część między " - " a "PLN"
        -- jedna kwota: = min
        NULLIF(
            REPLACE(
                REGEXP_REPLACE(
                    CASE
                        WHEN salary_item ~ '\d\s+-\s+\d'
                        THEN SPLIT_PART(
                                SPLIT_PART(salary_item, ' - ', 2),
                                'PLN', 1
                             )
                        ELSE SPLIT_PART(salary_item, 'PLN', 1)
                    END,
                    '[^0-9.]', '', 'g'
                ), ',', '.'
            ), ''
        )::NUMERIC                                              AS salary_max_raw,

        -- currency: zawsze PLN dla justjoin.it
        'PLN'                                                   AS currency,

        -- contract_type: po ostatnim " - "
        -- widełki → 3 część, jedna kwota → 2 część
        NULLIF(TRIM(
            CASE
                WHEN salary_item ~ '\d\s+-\s+\d'
                THEN SPLIT_PART(salary_item, ' - ', 3)
                ELSE SPLIT_PART(salary_item, ' - ', 2)
            END
        ), '')                                                  AS raw_contract,

        -- salary_type: Net → NETTO, Gross → BRUTTO, B2B zawsze NETTO
        CASE
            WHEN salary_item ILIKE '%PLNNet%'   THEN 'NETTO'
            WHEN salary_item ILIKE '%B2B%'      THEN 'NETTO'
            WHEN salary_item ILIKE '%PLNGross%' THEN 'BRUTTO'
            ELSE 'BRUTTO'
        END                                                     AS salary_type,

        -- period raw
        CASE
            WHEN salary_item ILIKE '%per hour%'  THEN 'hour'
            WHEN salary_item ILIKE '%per month%' THEN 'month'
			WHEN salary_item ILIKE '%per day%' 	 THEN 'day'
			WHEN salary_item ILIKE '%per year%' 	 THEN 'year'
            ELSE NULL
        END                                                     AS period_raw

    FROM filtered
),

-- Korekcja period: salary_min < 2000 → na pewno HOURLY (błąd rekrutera)
corrected AS (
    SELECT
        bronze_file_id,
        offer_date,
        source_offer_id,
        salary_min_raw                                          AS salary_min,
        -- salary_max = salary_min gdy jedna kwota
        COALESCE(salary_max_raw, salary_min_raw)                AS salary_max,
        currency,
        salary_type,
        raw_contract,

        CASE
            --WHEN salary_min_raw < 1000 and  period_raw <> 'day' 	THEN 'HOURLY'
            WHEN period_raw = 'hour' and salary_min_raw < 1000    	THEN 'HOURLY'
			WHEN period_raw = 'day'     							THEN 'DAILY'
			WHEN period_raw = 'month'   							THEN 'MONTHLY'
			WHEN period_raw = 'year'   								THEN 'ANNUALLY'
            ELSE NULL
        END                                                     AS period

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
            WHEN raw_contract ILIKE '%B2B%'                     THEN 'B2B'
            WHEN raw_contract ILIKE '%Permanent%'
              OR raw_contract ILIKE '%UoP%'
              OR raw_contract ILIKE '%employm%'                 THEN 'UoP'
            WHEN raw_contract ILIKE '%Mandate%'
              OR raw_contract ILIKE '%zlecen%'                  THEN 'Umowa zlecenie'
            WHEN raw_contract ILIKE '%Internship%'
              OR raw_contract ILIKE '%staż%'
              OR raw_contract ILIKE '%praktyki%'                THEN 'Umowa o staż'
            WHEN raw_contract ILIKE '%Zastępstwo%'              THEN 'Umowa na zastępstwo'
			WHEN raw_contract ILIKE '%specific%'            	THEN 'Umowa o dzieło'
            ELSE raw_contract
        END                                                     AS contract_type
		
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
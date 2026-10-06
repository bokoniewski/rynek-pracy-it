-- models/intermediate/int_all__offer_locations.sql
-- Parsowanie lokalizacji ze wszystkich portali → jeden rekord per lokalizacja per oferta
-- pracuj   → surowy string z miastem w nawiasie
-- nofluff  → JSONB lista z miastem przed \n
-- joinit   → osobne kolumny city, country
-- protocol → "miasto, region"

{{ config(materialized='ephemeral') }}

WITH pracuj AS (
    SELECT
        'pracuj'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        NULLIF(TRIM(
            REGEXP_REPLACE(
                SPLIT_PART(
                    REPLACE(employer_address, 'Company location: ', ''),
                    '(', 1
                ),
                '^.*,\s*', ''
            )
        ), '')                                  AS city,
        NULLIF(TRIM(
            SUBSTRING(
                REPLACE(employer_address, 'Company location: ', ''),
                '\(([^)]+)\)[^(]*$'
            )
        ), '')                                  AS region,
        'PL'                                    AS country
    FROM {{ ref('stg_pracuj') }}
    WHERE employer_address IS NOT NULL
),

nofluff AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(SPLIT_PART(SPLIT_PART(value, E'\n', 1), ',', 1)) AS city,
        NULL::TEXT                              AS region,
        'PL'                                    AS country
    FROM {{ ref('stg_nofluff') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(employer_address) AS value
    WHERE value !~ '\d'
      AND value NOT ILIKE '%zdalna%'
      AND value NOT ILIKE '%remote%'
      AND value NOT ILIKE '%N/A%'
      AND LOWER(TRIM(value)) NOT IN ('poland', 'polska')
      AND employer_address IS NOT NULL
),

joinit AS (
    SELECT
        'joinit'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        city,
        region,
        UPPER(country)                          AS country
    FROM {{ ref('stg_joinit') }}
    WHERE city IS NOT NULL
      AND city NOT ILIKE '%remote%'
      AND city NOT ILIKE '%hybrid%'
      AND city !~ '\d'
      AND city NOT IN ('Poland')
),

protocol AS (
    SELECT
        'protocol'                              AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(SPLIT_PART(employer_address, ',', 1)) AS city,
        TRIM(SPLIT_PART(employer_address, ',', 2)) AS region,
        'PL'                                    AS country
    FROM {{ ref('stg_protocol') }}
    WHERE employer_address IS NOT NULL
      AND employer_address NOT ILIKE '%abroad%'
      AND employer_address !~ '\d'
)

SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    NULLIF(TRIM(city), '')      AS city,
    NULLIF(TRIM(region), '')    AS region,
    NULLIF(TRIM(country), '')   AS country
FROM (
    SELECT * FROM pracuj
    UNION ALL
    SELECT * FROM nofluff
    UNION ALL
    SELECT * FROM joinit
    UNION ALL
    SELECT * FROM protocol
) all_locations
WHERE city IS NOT NULL
  AND TRIM(city) != ''
-- models/intermediate/int_all__offer_specs.sql
-- Parsowanie specjalizacji ze wszystkich portali → jeden rekord per specjalizacja per oferta
-- pracuj   → split po ',' potem po '&'
-- nofluff  → jsonb_array_elements_text
-- joinit   → jeden rekord
-- protocol → brak kolumny

{{ config(materialized='ephemeral') }}

WITH pracuj AS (
    SELECT
        'pracuj'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value2)                            AS specialization_name
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL string_to_table(specialization, ',') AS value1
    CROSS JOIN LATERAL string_to_table(value1, '&amp;') AS value2
    WHERE specialization IS NOT NULL
      AND TRIM(value2) != ''
      AND TRIM(value2) != 'N/A'
),

nofluff AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        jsonb_array_elements_text(specialization) AS specialization_name
    FROM {{ ref('stg_nofluff') }}
    WHERE specialization IS NOT NULL
),

joinit AS (
    SELECT
        'joinit'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        specialization                          AS specialization_name
    FROM {{ ref('stg_joinit') }}
    WHERE specialization IS NOT NULL
      AND specialization != 'N/A'
)

SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    specialization_name
FROM (
    SELECT * FROM pracuj
    UNION ALL
    SELECT * FROM nofluff
    UNION ALL
    SELECT * FROM joinit
) all_specs
WHERE specialization_name IS NOT NULL
  AND TRIM(specialization_name) != ''
  AND TRIM(specialization_name) != 'N/A'
-- models/intermediate/int_all__offer_responsibilities.sql
-- Parsowanie obowiązków ze wszystkich portali → jeden rekord per resp per oferta
-- nofluff  → responsibilities
-- protocol → offer_responsibilities
-- pracuj   → responsibilities
-- joinit   → brak kolumny

{{ config(materialized='ephemeral') }}

WITH nofluff AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS resp_name
    FROM {{ ref('stg_nofluff') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(responsibilities) AS value
    WHERE responsibilities IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

protocol AS (
    SELECT
        'protocol'                              AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS resp_name
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(offer_responsibilities) AS value
    WHERE offer_responsibilities IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

pracuj AS (
    SELECT
        'pracuj'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS resp_name
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(responsibilities) AS value
    WHERE responsibilities IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
)


SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    resp_name
FROM (
    SELECT * FROM nofluff
    UNION ALL
    SELECT * FROM protocol
    UNION ALL
    SELECT * FROM pracuj
) all_resp
WHERE resp_name IS NOT NULL
  AND TRIM(resp_name) != ''
  AND TRIM(resp_name) != 'N/A'
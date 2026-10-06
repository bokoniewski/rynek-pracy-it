-- models/intermediate/int_all__offer_benefits.sql
-- Parsowanie benefitów ze wszystkich portali → jeden rekord per benefit per oferta
-- nofluff  → office_benefits (udogodnienia biurowe) + benefits (benefity pracownicze)
-- protocol → offer_benefits
-- pracuj   → benefits
-- joinit   → brak kolumny z benefitami

{{ config(materialized='ephemeral') }}

WITH nofluff_office AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS benefit_name
    FROM {{ ref('stg_nofluff') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(office_benefits) AS value
    WHERE office_benefits IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

nofluff_benefits AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS benefit_name
    FROM {{ ref('stg_nofluff') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(benefits) AS value
    WHERE benefits IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

protocol AS (
    SELECT
        'protocol'                              AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS benefit_name
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(offer_benefits) AS value
    WHERE offer_benefits IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

pracuj AS (
    SELECT
        'pracuj'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS benefit_name
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(benefits) AS value
    WHERE benefits IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
)

SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    benefit_name
FROM (
    SELECT * FROM nofluff_office
    UNION ALL
    SELECT * FROM nofluff_benefits
    UNION ALL
    SELECT * FROM protocol
    UNION ALL
    SELECT * FROM pracuj
) all_benefits
WHERE benefit_name IS NOT NULL
  AND TRIM(benefit_name) != ''
  AND TRIM(benefit_name) != 'N/A'
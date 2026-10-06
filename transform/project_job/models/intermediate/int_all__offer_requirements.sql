-- models/intermediate/int_all__offer_requirements.sql
-- Parsowanie wymagań ze wszystkich portali → jeden rekord per requirements per oferta
-- pracuj  	→ requirements_expected, requirements_optional 
-- joinit 	→ brak kolumny
-- nofluff  → requirements_expected, requirements_optional 
-- protocol → offer_requirements, offer_nice_to_have 

{{ config(materialized='ephemeral') }}

WITH pracuj_expected AS (
    SELECT
        'pracuj'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS req_name,
		1::integer								AS req_type_id
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(requirements_expected) AS value
    WHERE requirements_expected IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

pracuj_optional AS (
    SELECT
        'pracuj'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS req_name,
		2::integer								AS req_type_id
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(requirements_optional) AS value
    WHERE requirements_optional IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

nofluff_expected AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS req_name,
		1::integer								AS req_type_id
    FROM {{ ref('stg_nofluff') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(requirements_expected) AS value
    WHERE requirements_expected IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

nofluff_optional AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS req_name,
		2::integer								AS req_type_id
    FROM {{ ref('stg_nofluff') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(requirements_optional) AS value
    WHERE requirements_optional IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

protocol_expected AS (
    SELECT
        'protocol'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS req_name,
		1::integer								AS req_type_id
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(offer_requirements) AS value
    WHERE offer_requirements IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
),

protocol_optional AS (
    SELECT
        'protocol'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS req_name,
		2::integer								AS req_type_id
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(offer_nice_to_have) AS value
    WHERE offer_nice_to_have IS NOT NULL
      AND TRIM(value) != ''
      AND TRIM(value) != 'N/A'
)


SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    req_name,
	req_type_id
FROM (
    SELECT * FROM pracuj_expected
    UNION ALL
    SELECT * FROM pracuj_optional
    UNION ALL
    SELECT * FROM nofluff_expected
    UNION ALL
    SELECT * FROM nofluff_optional
	UNION ALL
    SELECT * FROM protocol_expected
    UNION ALL
    SELECT * FROM protocol_optional
) all_req
WHERE req_name IS NOT NULL
  AND TRIM(req_name) != ''
  AND TRIM(req_name) != 'N/A'
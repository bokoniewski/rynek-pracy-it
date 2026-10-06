-- models/intermediate/int_all__offer_technologies.sql
-- Parsowanie technologii ze wszystkich portali → jeden rekord per technologia per oferta
-- pracuj   → technology_expected (wymagane) + technology_optional (opcjonalne)
-- nofluff  → technology_expected (wymagane) + technology_optional (opcjonalne)
-- protocol → tech_required (wymagane) + tech_optional (opcjonalne)
-- joinit   → tech_stack (tylko wymagane, lista obiektów {name, level})

{{ config(materialized='ephemeral') }}

WITH pracuj_required AS (
    SELECT
        'pracuj'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS technology_name,
        'wymagane'                              AS requirement_type
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(technology_expected) AS value
    WHERE technology_expected IS NOT NULL
      AND TRIM(value) != 'N/A'
      AND TRIM(value) != ''
),

pracuj_optional AS (
    SELECT
        'pracuj'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS technology_name,
        'opcjonalne'                            AS requirement_type
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(technology_optional) AS value
    WHERE technology_optional IS NOT NULL
      AND TRIM(value) != 'N/A'
      AND TRIM(value) != ''
),

nofluff_required AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS technology_name,
        'wymagane'                              AS requirement_type
    FROM {{ ref('stg_nofluff') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(technology_expected) AS value
    WHERE technology_expected IS NOT NULL
      AND TRIM(value) != 'N/A'
      AND TRIM(value) != ''
),

nofluff_optional AS (
    SELECT
        'nofluff'                               AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS technology_name,
        'opcjonalne'                            AS requirement_type
    FROM {{ ref('stg_nofluff') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(technology_optional) AS value
    WHERE technology_optional IS NOT NULL
      AND TRIM(value) != 'N/A'
      AND TRIM(value) != ''
),

protocol_required AS (
    SELECT
        'protocol'                              AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS technology_name,
        'wymagane'                              AS requirement_type
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(tech_required) AS value
    WHERE tech_required IS NOT NULL
      AND TRIM(value) != 'N/A'
      AND TRIM(value) != ''
),

protocol_optional AS (
    SELECT
        'protocol'                              AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(value)                             AS technology_name,
        'opcjonalne'                            AS requirement_type
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL jsonb_array_elements_text(tech_optional) AS value
    WHERE tech_optional IS NOT NULL
      AND TRIM(value) != 'N/A'
      AND TRIM(value) != ''
),

-- joinit: tech_stack to lista obiektów {name, level} — tylko wymagane
joinit_required AS (
    SELECT
        'joinit'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(tech->>'name')                     AS technology_name,
        'wymagane'                              AS requirement_type
    FROM {{ ref('stg_joinit') }}
    CROSS JOIN LATERAL jsonb_array_elements(tech_stack) AS tech
    WHERE tech_stack IS NOT NULL
      AND TRIM(tech->>'name') != ''
      AND TRIM(tech->>'name') IS NOT NULL
),

all_technologies AS (
    SELECT * FROM pracuj_required
    UNION ALL
    SELECT * FROM pracuj_optional
    UNION ALL
    SELECT * FROM nofluff_required
    UNION ALL
    SELECT * FROM nofluff_optional
    UNION ALL
    SELECT * FROM protocol_required
    UNION ALL
    SELECT * FROM protocol_optional
    UNION ALL
    SELECT * FROM joinit_required
)

SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    technology_name,
    requirement_type
FROM all_technologies
WHERE technology_name IS NOT NULL
  AND TRIM(technology_name) != ''
  AND TRIM(technology_name) != 'N/A'
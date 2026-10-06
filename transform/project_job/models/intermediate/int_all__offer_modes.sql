-- models/intermediate/int_all__offer_modes.sql
-- Parsowanie trybów pracy ze wszystkich portali → jeden rekord per tryb per oferta
-- pracuj   → split po ','
-- protocol → split po '•'
-- nofluff  → logika z dwóch kolumn (job_modes + job_modes_2)
-- joinit   → jeden rekord

{{ config(materialized='ephemeral') }}

WITH pracuj AS (
    SELECT
        'pracuj'                            AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        CASE
            WHEN TRIM(LOWER(value)) ILIKE '%zdalna%'        THEN 'Remote'
            WHEN TRIM(LOWER(value)) ILIKE '%home office%'   THEN 'Remote'
            WHEN TRIM(LOWER(value)) ILIKE '%hybryd%'        THEN 'Hybrid'
            WHEN TRIM(LOWER(value)) ILIKE '%hybrid%'        THEN 'Hybrid'
            WHEN TRIM(LOWER(value)) ILIKE '%mobiln%'        THEN 'Mobile'
            WHEN TRIM(LOWER(value)) ILIKE '%mobile%'        THEN 'Mobile'
            WHEN TRIM(LOWER(value)) ILIKE '%stacjonarn%'    THEN 'Office'
            WHEN TRIM(LOWER(value)) ILIKE '%full office%'   THEN 'Office'
            ELSE 'Office'
        END                                 AS mode_name
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL string_to_table(job_modes, ',') AS value
    WHERE job_modes IS NOT NULL
),

nofluff AS (
    SELECT
        'nofluff'                           AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        CASE
            WHEN job_modes  ILIKE '%zdalna%'    THEN 'Remote'
            WHEN job_modes_2 ILIKE '%zdalna%'   THEN 'Remote'
            WHEN job_modes  ILIKE '%hybryd%'    THEN 'Hybrid'
            WHEN job_modes_2 ILIKE '%hybryd%'   THEN 'Hybrid'
            ELSE 'Office'
        END                                 AS mode_name
    FROM {{ ref('stg_nofluff') }}
    WHERE job_modes IS NOT NULL
       OR job_modes_2 IS NOT NULL
),

joinit AS (
    SELECT
        'joinit'                            AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
		job_modes 							AS mode_name
    FROM {{ ref('stg_joinit') }}
    WHERE job_modes IS NOT NULL
),

protocol AS (
    SELECT
        'protocol'                          AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        CASE
            WHEN TRIM(LOWER(value)) ILIKE '%zdalna%'        THEN 'Remote'
            WHEN TRIM(LOWER(value)) ILIKE '%remote%'        THEN 'Remote'
            WHEN TRIM(LOWER(value)) ILIKE '%hybrid%'        THEN 'Hybrid'
            WHEN TRIM(LOWER(value)) ILIKE '%hybryd%'        THEN 'Hybrid'
            WHEN TRIM(LOWER(value)) ILIKE '%stacjona%'      THEN 'Office'
            WHEN TRIM(LOWER(value)) ILIKE '%office%'        THEN 'Office'
            WHEN TRIM(LOWER(value)) ILIKE '%mobil%'         THEN 'Mobile'
            ELSE TRIM(LOWER(value))
        END                                 AS mode_name
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL string_to_table(job_modes, '•') AS value
    WHERE job_modes IS NOT NULL
),

all_modes AS (
    SELECT * FROM pracuj
    UNION ALL
    SELECT * FROM nofluff
    UNION ALL
    SELECT * FROM joinit
    UNION ALL
    SELECT * FROM protocol
)

SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    mode_name
FROM all_modes
WHERE mode_name IS NOT NULL
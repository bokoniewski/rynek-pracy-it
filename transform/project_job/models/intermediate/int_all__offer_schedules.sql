-- models/intermediate/int_all__offer_schedules.sql
-- Parsowanie wymiarów etatu ze wszystkich portali → jeden rekord per wymiar per oferta
-- pracuj   → split po ','
-- joinit   → jeden rekord
-- nofluff  → brak kolumny
-- protocol → brak kolumny

{{ config(materialized='ephemeral') }}

WITH pracuj AS (
    SELECT
        'pracuj'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(LOWER(value))                      AS raw_schedule
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL string_to_table(job_schedule, ',') AS value
    WHERE job_schedule IS NOT NULL
),

joinit AS (
    SELECT
        'joinit'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(LOWER(job_schedule))               AS raw_schedule
    FROM {{ ref('stg_joinit') }}
    WHERE job_schedule IS NOT NULL
),

all_schedules AS (
    SELECT * FROM pracuj
    UNION ALL
    SELECT * FROM joinit
),

mapped AS (
    SELECT
        portal,
        bronze_file_id,
        offer_date,
        source_offer_id,

        CASE
            -- Full-time
            WHEN raw_schedule LIKE '%full%'         THEN 'Pełny etat'
            WHEN raw_schedule LIKE '%pełny%'        THEN 'Pełny etat'

            -- Part-time
            WHEN raw_schedule LIKE '%part%'         THEN 'Część etatu'
            WHEN raw_schedule LIKE '%część%'        THEN 'Część etatu'

            -- Freelance
            WHEN raw_schedule LIKE '%freelance%'    THEN 'Zlecenie / Freelance'

            -- Temporary
            WHEN raw_schedule LIKE '%additional%'   THEN 'Praca tymczasowa'
            WHEN raw_schedule LIKE '%temporary%'    THEN 'Praca tymczasowa'
            WHEN raw_schedule LIKE '%dodatkow%'     THEN 'Praca tymczasowa'
            WHEN raw_schedule LIKE '%tymczasow%'    THEN 'Praca tymczasowa'

            -- Internship
            WHEN raw_schedule LIKE '%internship%'   THEN 'Staż'
            WHEN raw_schedule LIKE '%practice%'     THEN 'Staż'

            ELSE NULL
        END                                     AS schedule_name

    FROM all_schedules
    WHERE raw_schedule IS NOT NULL
      AND raw_schedule != 'n/a'
      AND raw_schedule != ''
)

SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    schedule_name
FROM mapped
WHERE schedule_name IS NOT NULL
-- models/intermediate/int_all__offer_levels.sql
-- Parsowanie poziomów stanowiska ze wszystkich portali → jeden rekord per poziom per oferta
-- pracuj   → split po ','  (może być kilka poziomów)
-- protocol → split po '•'  (może być kilka poziomów)
-- nofluff  → jeden rekord
-- joinit   → jeden rekord

{{ config(materialized='ephemeral') }}

WITH pracuj AS (
    SELECT
        'pracuj'                            AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(LOWER(value))                  AS raw_level
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL string_to_table(employment_type, ',') AS value
    WHERE employment_type IS NOT NULL
),

protocol AS (
    SELECT
        'protocol'                          AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(LOWER(value))                  AS raw_level
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL string_to_table(employment_type, '•') AS value
    WHERE employment_type IS NOT NULL
),

nofluff AS (
    SELECT
        'nofluff'                           AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(LOWER(employment_type))        AS raw_level
    FROM {{ ref('stg_nofluff') }}
    WHERE employment_type IS NOT NULL
),

joinit AS (
    SELECT
        'joinit'                            AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(LOWER(employment_type))        AS raw_level
    FROM {{ ref('stg_joinit') }}
    WHERE employment_type IS NOT NULL
),

all_levels AS (
    SELECT * FROM pracuj
    UNION ALL
    SELECT * FROM protocol
    UNION ALL
    SELECT * FROM nofluff
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
            -- Trainee
            WHEN raw_level LIKE '%trainee%'         THEN 'Trainee'
            WHEN raw_level LIKE '%praktykant%'      THEN 'Trainee'
            WHEN raw_level LIKE '%stażyst%'         THEN 'Trainee'
            WHEN raw_level LIKE '%asystent%'        THEN 'Trainee'
            WHEN raw_level LIKE '%assistant%'       THEN 'Trainee'

            -- Junior
            WHEN raw_level LIKE '%junior%'          THEN 'Junior'
            WHEN raw_level LIKE '%młodszy%'         THEN 'Junior'
            WHEN raw_level LIKE '%młodsza%'         THEN 'Junior'

            -- Senior (przed Mid bo "starszy specjalista" zawiera "specjalista")
            WHEN raw_level LIKE '%senior%'          THEN 'Senior'
            WHEN raw_level LIKE '%starszy%'         THEN 'Senior'
            WHEN raw_level LIKE '%starsza%'         THEN 'Senior'

            -- Expert
            WHEN raw_level LIKE '%expert%'          THEN 'Expert'
            WHEN raw_level LIKE '%ekspert%'         THEN 'Expert'

            -- Mid
            WHEN raw_level LIKE '%mid%'             THEN 'Mid'
            WHEN raw_level LIKE '%regular%'         THEN 'Mid'
            WHEN raw_level LIKE '%specialist%'      THEN 'Mid'
            WHEN raw_level LIKE '%specjalista%'     THEN 'Mid'
            WHEN raw_level LIKE '%specjalistka%'    THEN 'Mid'

            -- Lead (przed Manager bo "team manager" zawiera "manager")
            WHEN raw_level LIKE '%team manager%'    THEN 'Lead'
            WHEN raw_level LIKE '%lead%'            THEN 'Lead'
            WHEN raw_level LIKE '%head%'            THEN 'Lead'

            -- Manager
            WHEN raw_level LIKE '%manager%'         THEN 'Manager'
            WHEN raw_level LIKE '%kierownik%'       THEN 'Manager'
            WHEN raw_level LIKE '%kierowniczka%'    THEN 'Manager'
            WHEN raw_level LIKE '%koordynator%'     THEN 'Manager'
            WHEN raw_level LIKE '%menedżer%'        THEN 'Manager'
            WHEN raw_level LIKE '%supervisor%'      THEN 'Manager'
            WHEN raw_level LIKE '%c-level%'         THEN 'Manager'

            -- Director
            WHEN raw_level LIKE '%director%'        THEN 'Director'
            WHEN raw_level LIKE '%dyrektor%'        THEN 'Director'
            WHEN raw_level LIKE '%executive%'       THEN 'Director'

            ELSE raw_level
        END                                         AS level_name

    FROM all_levels
    WHERE raw_level IS NOT NULL
      AND raw_level != 'n/a'
      AND raw_level != ''
)

SELECT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    level_name
FROM mapped
WHERE level_name IS NOT NULL
-- models/intermediate/int_all__offer_contracts.sql
-- Parsowanie typów umów ze wszystkich portali → jeden rekord per typ umowy per oferta
-- pracuj   → split po ',' z job_contract
-- joinit   → split po ',' z job_contract
-- nofluff  → z offer_salaries.contract_type (brak osobnej kolumny w stg)
-- protocol → z offer_salaries.contract_type (brak osobnej kolumny w stg)

{{ config(materialized='ephemeral') }}

WITH pracuj AS (
    SELECT
        'pracuj'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(LOWER(value))                      AS raw_contract
    FROM {{ ref('stg_pracuj') }}
    CROSS JOIN LATERAL string_to_table(job_contract, ',') AS value
    WHERE job_contract IS NOT NULL
),

joinit AS (
    SELECT
        'joinit'                                AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        TRIM(LOWER(value))                      AS raw_contract
    FROM {{ ref('stg_joinit') }}
    CROSS JOIN LATERAL string_to_table(job_contract, ',') AS value
    WHERE job_contract IS NOT NULL
),

-- nofluff i protocol: bierzemy już znormalizowane contract_type z offer_salaries
-- JOIN przez offers aby dostać bronze_file_id, offer_date, source_offer_id
nofluff AS (
    SELECT
        'nofluff'                               AS portal,
        o.bronze_file_id,
        o.offer_date,
        o.source_offer_id,
        LOWER(ofs.contract_type)                AS raw_contract
    FROM {{ source('silver', 'offer_salaries') }} ofs
    INNER JOIN {{ source('silver', 'offers') }} o
        ON ofs.offer_id = o.id
    WHERE o.portal_id = (
        SELECT id FROM {{ source('silver', 'def_portal') }}
        WHERE portal_name = 'nofluff'
    )
    AND ofs.contract_type IS NOT NULL
    AND ofs.contract_type != 'Any'
),

protocol AS (
    SELECT
        'protocol'                                      AS portal,
        bronze_file_id,
        offer_date,
        source_offer_id,
        LOWER(TRIM(salary_item->>'contract_type'))             AS raw_contract
    FROM {{ ref('stg_protocol') }}
    CROSS JOIN LATERAL jsonb_array_elements(salary_info) AS salary_item
    WHERE salary_info IS NOT NULL
      AND salary_info::text != '[]'
      AND TRIM(salary_item->>'contract_type') IS NOT NULL
      AND TRIM(salary_item->>'contract_type') != ''
      AND TRIM(salary_item->>'contract_type') NOT ILIKE '%N/A%'
),

all_contracts AS (
    SELECT * FROM pracuj
    UNION ALL
    SELECT * FROM joinit
    UNION ALL
    SELECT * FROM nofluff
    UNION ALL
    SELECT * FROM protocol
),

mapped AS (
    SELECT
        portal,
        bronze_file_id,
        offer_date,
        source_offer_id,

        CASE
            -- B2B
            WHEN raw_contract LIKE '%b2b%'                  THEN 'B2B'

            -- UoP
            WHEN raw_contract LIKE '%umow%pracę%'           THEN 'UoP'
            WHEN raw_contract LIKE '%contract of employ%'   THEN 'UoP'
            WHEN raw_contract LIKE '%permanent%'            THEN 'UoP'
            WHEN raw_contract LIKE '%uop%'                  THEN 'UoP'

            -- Umowa zlecenie
            WHEN raw_contract LIKE '%zlecen%'               THEN 'Umowa zlecenie'
            WHEN raw_contract LIKE '%mandate%'              THEN 'Umowa zlecenie'

            -- Umowa o dzieło
            WHEN raw_contract LIKE '%dzieło%'               THEN 'Umowa o dzieło'
            WHEN raw_contract LIKE '%specific-task%'        THEN 'Umowa o dzieło'

            -- Umowa o staż
            WHEN raw_contract LIKE '%staż%'                 THEN 'Umowa o staż'
            WHEN raw_contract LIKE '%praktyk%'              THEN 'Umowa o staż'
            WHEN raw_contract LIKE '%internship%'           THEN 'Umowa o staż'
            WHEN raw_contract LIKE '%apprenticeship%'       THEN 'Umowa o staż'

            -- Umowa na zastępstwo
            WHEN raw_contract LIKE '%zastępstwo%'           THEN 'Umowa na zastępstwo'
			WHEN raw_contract LIKE '%temporary%'            THEN 'Umowa na zastępstwo'
			WHEN raw_contract LIKE '%substitution%'         THEN 'Umowa na zastępstwo'
            ELSE raw_contract
        END                                                 AS contract_name

    FROM all_contracts
    WHERE raw_contract IS NOT NULL
      AND lower(raw_contract) != 'any'
      AND raw_contract != ''
)

SELECT DISTINCT
    portal,
    bronze_file_id,
    offer_date,
    source_offer_id,
    contract_name
FROM mapped
WHERE contract_name IS NOT NULL
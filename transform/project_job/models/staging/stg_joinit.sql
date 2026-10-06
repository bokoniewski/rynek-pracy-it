-- models/staging/stg_justit.sql
-- Czyszczenie i rename kolumn z bronze.raw_offers_joinit
-- Brak logiki biznesowej — tylko trim, cast, rename
-- wywolanie w cmd: dbt run --profiles-dir . --select stg_joinit --vars "{\"FILE_DATE\": \"2026-03-23\"}"

{{ config(materialized='view') }}


-- Pobierz bronze_file_id z audit_file_log po nazwie pliku źródłowego
with audit AS (
    SELECT
        file_id,
		file_date
    FROM {{ source('bronze', 'audit_file_log') }}
    WHERE portal = 'joinit'
      AND status IN ('SUCCESS', 'PARTIAL')
	  AND file_date = '{{ var("FILE_DATE", "1899-12-30") }}'
)

SELECT
    raw_id,
    loaded_at,
	audit.file_id                               		AS bronze_file_id,
	
	-- Identyfikacja oferty
    offer_id                                            AS source_offer_id,
    url,
	
	-- Dane oferty — trim + nullif (zamienia pusty string na NULL)
    NULLIF(TRIM(title), '')                             AS title,
    NULLIF(TRIM(employer), '')                          AS company_name,
    NULLIF(TRIM(seniority), '')                         AS employment_type,
    NULLIF(TRIM(job_schedule), '')                      AS job_schedule,
    NULLIF(TRIM(job_contract), '')                      AS job_contract,
    NULLIF(TRIM(job_mode), '')                          AS job_modes,
    NULLIF(TRIM(specialization), '')                    AS specialization,

    -- Lokalizacja już rozbita w Bronze
    NULLIF(TRIM(location_city), '')                     AS city,
    NULLIF(TRIM(location_region), '')                   AS region,
    NULLIF(TRIM(location_street), '')                   AS street,
    NULLIF(TRIM(location_postal_code), '')              AS postal_code,
    NULLIF(TRIM(location_country), '')                  AS country,
	
	-- JSONB pola — zostawiamy as-is, parsujemy w intermediate
    tech_stack,
	salary,
	
	-- Metadane portalu
	'joinit'                                       		AS portal,
    CAST(audit.file_date AS DATE)                       AS offer_date

    

FROM {{ source('bronze', 'raw_offers_joinit') }} raw_joinit
INNER JOIN audit
    ON raw_joinit.source_file_id = audit.file_id        -- łączymy po ID pliku 
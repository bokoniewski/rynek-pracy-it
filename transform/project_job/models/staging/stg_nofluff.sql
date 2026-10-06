
-- models/staging/stg_nofluff.sql
-- Czyszczenie i rename kolumn z bronze.raw_offers_nofluff
-- Brak logiki biznesowej — tylko trim, cast, rename
-- wywolanie w cmd: dbt run --profiles-dir . --select stg_nofluff --vars "{\"FILE_DATE\": \"2026-03-23\"}"

{{ config(materialized='view') }}


-- Pobierz bronze_file_id z audit_file_log po nazwie pliku źródłowego
with audit AS (
    SELECT
        file_id,
		file_date
    FROM {{ source('bronze', 'audit_file_log') }}
    WHERE portal = 'nofluff'
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
    NULLIF(TRIM(job_title), '')                         AS title,
    NULLIF(TRIM(employer), '')                          AS company_name,
    NULLIF(TRIM(job_level), '')                         AS employment_type,
    NULLIF(TRIM(job_modes), '')                         AS job_modes,
    NULLIF(TRIM(job_modes_2), '')                       AS job_modes_2,

    -- JSONB pola
	specialization,
    employer_address,
    salary_info,
    technology_expected,
    technology_optional,
    requirements_expected,
    requirements_optional,
    responsibilities,
    details_responsibilities,
    office_benefits,
    benefits,
	
	-- Metadane portalu
    'nofluff'                                   		AS portal,
    CAST(audit.file_date AS DATE)                       AS offer_date

FROM {{ source('bronze', 'raw_offers_nofluff') }} raw_nofluff
INNER JOIN audit
    ON raw_nofluff.source_file_id = audit.file_id        -- łączymy po ID pliku 
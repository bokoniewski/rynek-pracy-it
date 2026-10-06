-- models/staging/stg_pracuj.sql
-- Czyszczenie i rename kolumn z bronze.raw_offers_pracuj
-- Brak logiki biznesowej — tylko trim, cast, rename
-- wywolanie w cmd: dbt run --profiles-dir . --select stg_pracuj --vars "{\"FILE_DATE\": \"2026-03-23\"}"

{{ config(materialized='view') }}


-- Pobierz bronze_file_id z audit_file_log po nazwie pliku źródłowego
with audit AS (
    SELECT
        file_id,
		file_date
    FROM {{ source('bronze', 'audit_file_log') }}
    WHERE portal = 'pracuj'
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
    NULLIF(TRIM(employer_address), '')                  AS employer_address,
    NULLIF(TRIM(job_workplace), '')                     AS job_workplace,
    NULLIF(TRIM(job_contract), '')                      AS job_contract,
    NULLIF(TRIM(job_schedule), '')                      AS job_schedule,
    NULLIF(TRIM(employment_type), '')                   AS employment_type,
    NULLIF(TRIM(job_modes), '')                         AS job_modes,
    NULLIF(TRIM(specialization), '')                    AS specialization,

    -- JSONB pola — zostawiamy as-is, parsujemy w intermediate
    salary_info,
    technology_expected,
    technology_optional,
    responsibilities,
    requirements_expected,
    requirements_optional,
    offered,
    benefits,

    -- Metadane portalu
    'pracuj'                                         	AS portal,
    CAST(audit.file_date AS DATE)                       AS offer_date

FROM {{ source('bronze', 'raw_offers_pracuj') }} raw_pracuj
INNER JOIN audit
    ON raw_pracuj.source_file_id = audit.file_id        -- łączymy po ID pliku 
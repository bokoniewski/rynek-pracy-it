-- models/staging/stg_protocol.sql
-- Czyszczenie i rename kolumn z bronze.raw_offers_protocol
-- Brak logiki biznesowej — tylko trim, cast, rename
-- wywolanie w cmd: dbt run --profiles-dir . --select stg_protocol --vars "{\"FILE_DATE\": \"2026-03-23\"}"

{{ config(materialized='view') }}


-- Pobierz bronze_file_id z audit_file_log po nazwie pliku źródłowego
with audit AS (
    SELECT
        file_id,
		file_date
    FROM {{ source('bronze', 'audit_file_log') }}
    WHERE portal = 'protocol'
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
    NULLIF(TRIM(offer_title), '')                       AS title,
    NULLIF(TRIM(offer_company), '')                     AS company_name,
    NULLIF(TRIM(offer_level), '')                       AS employment_type,
    NULLIF(TRIM(offer_modes), '')                       AS job_modes,
    NULLIF(TRIM(offer_location), '')                    AS employer_address,

    -- JSONB pola
    salary_info,
    tech_required,
    tech_optional,
    offer_responsibilities,
    offer_requirements,
    offer_nice_to_have,
    offer_offered,
    offer_benefits,

    'protocol'                                    		AS portal,
    CAST(audit.file_date AS DATE)                       AS offer_date

FROM {{ source('bronze', 'raw_offers_protocol') }} raw_protocol
INNER JOIN audit
    ON raw_protocol.source_file_id = audit.file_id        -- łączymy po ID pliku 
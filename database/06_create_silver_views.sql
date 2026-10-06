-- =============================================================================
-- SKRYPT: Widoki pomocnicze do sprawdzenia poprawności wgrywanych danych – warstwa BRONZE, SILVER
-- PROJEKT: Project_job
-- OPIS: Gotowy create view dla warstwy BRONZE i SILVER
-- KOLEJNOŚĆ WYKONANIA: 7
-- ZALEŻNOŚCI: 01_schemas.sql, 02_bronze_tables.sql, 03_silver_tables.sql, 04_gold_tables.sql
-- =============================================================================





--- -----------------------------------------------------------------------------
-- Widok: bronze.v_test_data_raw_offers
-- OPIS: sprawdzenie czy wgrywane dane z JSON do bazy danych śą poprawne (czy obligatoryjne kolumny są wypełnione danymi)
--		 widok pomaga wskazać, które oferty nie zostały poprawnie wgrane  
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW bronze.v_test_data_raw_offers
 AS
 WITH test_data AS (
         SELECT 'protocol'::text AS portal,
            raw_offers_protocol.offer_id,
            NULLIF(TRIM(BOTH FROM concat_ws(', '::text,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_protocol.offer_title), ''::text) IS NULL OR upper(raw_offers_protocol.offer_title) = 'N/A'::text THEN 'offer_title'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_protocol.offer_company), ''::text) IS NULL OR upper(raw_offers_protocol.offer_company) = 'N/A'::text THEN 'offer_company'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_protocol.offer_level), ''::text) IS NULL OR upper(raw_offers_protocol.offer_level) = 'N/A'::text THEN 'offer_level'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_protocol.offer_modes), ''::text) IS NULL OR upper(raw_offers_protocol.offer_modes) = 'N/A'::text THEN 'offer_modes'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_protocol.offer_location), ''::text) IS NULL OR upper(raw_offers_protocol.offer_location) = 'N/A'::text THEN 'offer_location'::text
                    ELSE NULL::text
                END)), ''::text) AS brakujace_dane
           FROM bronze.raw_offers_protocol
          WHERE raw_offers_protocol.loaded_at::date = now()::date
        UNION ALL
         SELECT 'nofluff'::text AS portal,
            raw_offers_nofluff.offer_id,
            NULLIF(TRIM(BOTH FROM concat_ws(', '::text,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_nofluff.job_title), ''::text) IS NULL OR upper(raw_offers_nofluff.job_title) = 'N/A'::text THEN 'job_title'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_nofluff.employer), ''::text) IS NULL OR upper(raw_offers_nofluff.employer) = 'N/A'::text THEN 'employer'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN raw_offers_nofluff.specialization IS NULL OR raw_offers_nofluff.specialization = '[]'::jsonb OR raw_offers_nofluff.specialization = '[""]'::jsonb OR upper(raw_offers_nofluff.specialization::text) = '["N/A"]'::text THEN 'specialization'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_nofluff.job_level), ''::text) IS NULL OR upper(raw_offers_nofluff.job_level) = 'N/A'::text THEN 'job_level'::text
                    ELSE NULL::text
                END)), ''::text) AS brakujace_dane
           FROM bronze.raw_offers_nofluff
          WHERE raw_offers_nofluff.loaded_at::date = now()::date
        UNION ALL
         SELECT 'pracuj'::text AS portal,
            raw_offers_pracuj.offer_id,
            NULLIF(TRIM(BOTH FROM concat_ws(', '::text,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_pracuj.title), ''::text) IS NULL OR upper(raw_offers_pracuj.title) = 'N/A'::text THEN 'title'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_pracuj.employer), ''::text) IS NULL OR upper(raw_offers_pracuj.employer) = 'N/A'::text THEN 'employer'::text
                    ELSE NULL::text
                END)), ''::text) AS brakujace_dane
           FROM bronze.raw_offers_pracuj
          WHERE raw_offers_pracuj.loaded_at::date = now()::date
        UNION ALL
         SELECT 'joinit'::text AS portal,
            raw_offers_joinit.offer_id,
            NULLIF(TRIM(BOTH FROM concat_ws(', '::text,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_joinit.title), ''::text) IS NULL OR raw_offers_joinit.title = 'N/A'::text THEN 'title'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_joinit.employer), ''::text) IS NULL OR upper(raw_offers_joinit.employer) = 'N/A'::text THEN 'employer'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN NULLIF(TRIM(BOTH FROM raw_offers_joinit.specialization), ''::text) IS NULL OR upper(raw_offers_joinit.specialization) = 'N/A'::text THEN 'specialization'::text
                    ELSE NULL::text
                END)), ''::text) AS brakujace_dane
           FROM bronze.raw_offers_joinit
          WHERE raw_offers_joinit.loaded_at::date = now()::date
        )
 SELECT portal,
    offer_id,
    brakujace_dane
   FROM test_data
  WHERE brakujace_dane IS NOT NULL;



--- -----------------------------------------------------------------------------
-- Widok: bronze.v_test_double_raw_offers
-- OPIS: sprawdzenie czy mamy duble wgranych ofert
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW bronze.v_test_double_raw_offers
 AS
 SELECT 'nofluff'::text AS portal,
    raw_offers_nofluff.offer_id,
    'TAK'::text AS double
   FROM bronze.raw_offers_nofluff
  WHERE raw_offers_nofluff.loaded_at::date = now()::date
  GROUP BY raw_offers_nofluff.offer_id
 HAVING count(*) > 1
UNION ALL
 SELECT 'pracuj'::text AS portal,
    raw_offers_pracuj.offer_id,
    'TAK'::text AS double
   FROM bronze.raw_offers_pracuj
  WHERE raw_offers_pracuj.loaded_at::date = now()::date
  GROUP BY raw_offers_pracuj.offer_id
 HAVING count(*) > 1
UNION ALL
 SELECT 'joinit'::text AS portal,
    raw_offers_joinit.offer_id,
    'TAK'::text AS double
   FROM bronze.raw_offers_joinit
  WHERE raw_offers_joinit.loaded_at::date = now()::date
  GROUP BY raw_offers_joinit.offer_id
 HAVING count(*) > 1
UNION ALL
 SELECT 'protocol'::text AS portal,
    raw_offers_protocol.offer_id,
    'TAK'::text AS double
   FROM bronze.raw_offers_protocol
  WHERE raw_offers_protocol.loaded_at::date = now()::date
  GROUP BY raw_offers_protocol.offer_id
 HAVING count(*) > 1;





--- -----------------------------------------------------------------------------
-- Widok: silver.stg_joinit
-- OPIS: przygotowane dane z bronze.raw_offers_joinit dla porcesu dbt, który wgrywa dane do SILVER
--		 widok jest przebudowywany przy pomocy dbt stg_...  
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.stg_joinit
 AS
 WITH audit AS (
         SELECT audit_file_log.file_id,
            audit_file_log.file_date
           FROM bronze.audit_file_log
          WHERE audit_file_log.portal = 'joinit'::text AND (audit_file_log.status = ANY (ARRAY['SUCCESS'::text, 'PARTIAL'::text])) AND file_date = now()::date
        )
 SELECT raw_joinit.raw_id,
    raw_joinit.loaded_at,
    audit.file_id AS bronze_file_id,
    raw_joinit.offer_id AS source_offer_id,
    raw_joinit.url,
    NULLIF(TRIM(BOTH FROM raw_joinit.title), ''::text) AS title,
    NULLIF(TRIM(BOTH FROM raw_joinit.employer), ''::text) AS company_name,
    NULLIF(TRIM(BOTH FROM raw_joinit.seniority), ''::text) AS employment_type,
    NULLIF(TRIM(BOTH FROM raw_joinit.job_schedule), ''::text) AS job_schedule,
    NULLIF(TRIM(BOTH FROM raw_joinit.job_contract), ''::text) AS job_contract,
    NULLIF(TRIM(BOTH FROM raw_joinit.job_mode), ''::text) AS job_modes,
    NULLIF(TRIM(BOTH FROM raw_joinit.specialization), ''::text) AS specialization,
    NULLIF(TRIM(BOTH FROM raw_joinit.location_city), ''::text) AS city,
    NULLIF(TRIM(BOTH FROM raw_joinit.location_region), ''::text) AS region,
    NULLIF(TRIM(BOTH FROM raw_joinit.location_street), ''::text) AS street,
    NULLIF(TRIM(BOTH FROM raw_joinit.location_postal_code), ''::text) AS postal_code,
    NULLIF(TRIM(BOTH FROM raw_joinit.location_country), ''::text) AS country,
    raw_joinit.tech_stack,
    raw_joinit.salary,
    'joinit'::text AS portal,
    audit.file_date AS offer_date
   FROM bronze.raw_offers_joinit raw_joinit
     JOIN audit ON raw_joinit.source_file_id = audit.file_id;
	 


--- -----------------------------------------------------------------------------
-- Widok: silver.stg_nofluff
-- OPIS: przygotowane dane z bronze.raw_offers_nofluff dla porcesu dbt, który wgrywa dane do SILVER
--		 widok jest przebudowywany przy pomocy dbt stg_...  
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.stg_nofluff
 AS
 WITH audit AS (
         SELECT audit_file_log.file_id,
            audit_file_log.file_date
           FROM bronze.audit_file_log
          WHERE audit_file_log.portal = 'nofluff'::text AND (audit_file_log.status = ANY (ARRAY['SUCCESS'::text, 'PARTIAL'::text])) AND file_date = now()::date
        )
 SELECT raw_nofluff.raw_id,
    raw_nofluff.loaded_at,
    audit.file_id AS bronze_file_id,
    raw_nofluff.offer_id AS source_offer_id,
    raw_nofluff.url,
    NULLIF(TRIM(BOTH FROM raw_nofluff.job_title), ''::text) AS title,
    NULLIF(TRIM(BOTH FROM raw_nofluff.employer), ''::text) AS company_name,
    NULLIF(TRIM(BOTH FROM raw_nofluff.job_level), ''::text) AS employment_type,
    NULLIF(TRIM(BOTH FROM raw_nofluff.job_modes), ''::text) AS job_modes,
    NULLIF(TRIM(BOTH FROM raw_nofluff.job_modes_2), ''::text) AS job_modes_2,
    raw_nofluff.specialization,
    raw_nofluff.employer_address,
    raw_nofluff.salary_info,
    raw_nofluff.technology_expected,
    raw_nofluff.technology_optional,
    raw_nofluff.requirements_expected,
    raw_nofluff.requirements_optional,
    raw_nofluff.responsibilities,
    raw_nofluff.details_responsibilities,
    raw_nofluff.office_benefits,
    raw_nofluff.benefits,
    'nofluff'::text AS portal,
    audit.file_date AS offer_date
   FROM bronze.raw_offers_nofluff raw_nofluff
     JOIN audit ON raw_nofluff.source_file_id = audit.file_id;



--- -----------------------------------------------------------------------------
-- Widok: silver.stg_pracuj
-- OPIS: przygotowane dane z bronze.raw_offers_pracuj dla porcesu dbt, który wgrywa dane do SILVER
--		 widok jest przebudowywany przy pomocy dbt stg_...  
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.stg_pracuj
 AS
 WITH audit AS (
         SELECT audit_file_log.file_id,
            audit_file_log.file_date
           FROM bronze.audit_file_log
          WHERE audit_file_log.portal = 'pracuj'::text AND (audit_file_log.status = ANY (ARRAY['SUCCESS'::text, 'PARTIAL'::text])) AND file_date = now()::date
        )
 SELECT raw_pracuj.raw_id,
    raw_pracuj.loaded_at,
    audit.file_id AS bronze_file_id,
    raw_pracuj.offer_id AS source_offer_id,
    raw_pracuj.url,
    NULLIF(TRIM(BOTH FROM raw_pracuj.title), ''::text) AS title,
    NULLIF(TRIM(BOTH FROM raw_pracuj.employer), ''::text) AS company_name,
    NULLIF(TRIM(BOTH FROM raw_pracuj.employer_address), ''::text) AS employer_address,
    NULLIF(TRIM(BOTH FROM raw_pracuj.job_workplace), ''::text) AS job_workplace,
    NULLIF(TRIM(BOTH FROM raw_pracuj.job_contract), ''::text) AS job_contract,
    NULLIF(TRIM(BOTH FROM raw_pracuj.job_schedule), ''::text) AS job_schedule,
    NULLIF(TRIM(BOTH FROM raw_pracuj.employment_type), ''::text) AS employment_type,
    NULLIF(TRIM(BOTH FROM raw_pracuj.job_modes), ''::text) AS job_modes,
    NULLIF(TRIM(BOTH FROM raw_pracuj.specialization), ''::text) AS specialization,
    raw_pracuj.salary_info,
    raw_pracuj.technology_expected,
    raw_pracuj.technology_optional,
    raw_pracuj.responsibilities,
    raw_pracuj.requirements_expected,
    raw_pracuj.requirements_optional,
    raw_pracuj.offered,
    raw_pracuj.benefits,
    'pracuj'::text AS portal,
    audit.file_date AS offer_date
   FROM bronze.raw_offers_pracuj raw_pracuj
     JOIN audit ON raw_pracuj.source_file_id = audit.file_id;
	 
	 
--- -----------------------------------------------------------------------------
-- Widok: silver.stg_protocol
-- OPIS: przygotowane dane z bronze.raw_offers_protocol dla porcesu dbt, który wgrywa dane do SILVER
--		 widok jest przebudowywany przy pomocy dbt stg_...  
--- -----------------------------------------------------------------------------


CREATE OR REPLACE VIEW silver.stg_protocol
 AS
 WITH audit AS (
         SELECT audit_file_log.file_id,
            audit_file_log.file_date
           FROM bronze.audit_file_log
          WHERE audit_file_log.portal = 'protocol'::text AND (audit_file_log.status = ANY (ARRAY['SUCCESS'::text, 'PARTIAL'::text])) AND file_date = now()::date
        )
 SELECT raw_protocol.raw_id,
    raw_protocol.loaded_at,
    audit.file_id AS bronze_file_id,
    raw_protocol.offer_id AS source_offer_id,
    raw_protocol.url,
    NULLIF(TRIM(BOTH FROM raw_protocol.offer_title), ''::text) AS title,
    NULLIF(TRIM(BOTH FROM raw_protocol.offer_company), ''::text) AS company_name,
    NULLIF(TRIM(BOTH FROM raw_protocol.offer_level), ''::text) AS employment_type,
    NULLIF(TRIM(BOTH FROM raw_protocol.offer_modes), ''::text) AS job_modes,
    NULLIF(TRIM(BOTH FROM raw_protocol.offer_location), ''::text) AS employer_address,
    raw_protocol.salary_info,
    raw_protocol.tech_required,
    raw_protocol.tech_optional,
    raw_protocol.offer_responsibilities,
    raw_protocol.offer_requirements,
    raw_protocol.offer_nice_to_have,
    raw_protocol.offer_offered,
    raw_protocol.offer_benefits,
    'protocol'::text AS portal,
    audit.file_date AS offer_date
   FROM bronze.raw_offers_protocol raw_protocol
     JOIN audit ON raw_protocol.source_file_id = audit.file_id;
	 
	 
	 
	 
--- -----------------------------------------------------------------------------
-- Widok: silver.v_test_data_offer_benefits
-- OPIS: Sprawdzenie, które benefity z tabeli silver nie pasują do pattern danego ustandaryzowanego benefitu z tabeli gold (dim) 
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.v_test_data_offer_benefits
 AS
 SELECT DISTINCT ot.benefit_name,
    count(*) AS cnt
   FROM silver.offer_benefits ot,
    silver.offers of
  WHERE NOT (EXISTS ( SELECT 1
           FROM gold.d_benefit dbe
          WHERE (EXISTS ( SELECT 1
                   FROM jsonb_array_elements_text(dbe.like_patterns) pattern(value)
                  WHERE lower(ot.benefit_name) ~~ pattern.value)))) AND ot.offer_id = of.id 
				  AND of.offer_date = (select max(offer_date) from silver.offers) -- sprawdzamy tylko ostatnio wgrane pliki
  GROUP BY ot.benefit_name
  ORDER BY (count(*)) DESC;
  
  
 

--- -----------------------------------------------------------------------------
-- Widok: silver.v_test_data_offer_contracts
-- OPIS: Sprawdzenie dla których ofert nie można było dopasować typ kontraktu 
--- -----------------------------------------------------------------------------

create or replace view silver.v_test_data_offer_contracts as
 SELECT ofc.id,
    ofc.offer_id,
    ofc.contract_name
   FROM silver.offer_contracts ofc,
    silver.offers of
  WHERE 1 = 1 AND ofc.offer_id = of.id 
  AND ofc.contract_name not in (select contract_name from gold.d_contract)
  AND of.offer_date = (select max(offer_date) from silver.offers) -- sprawdzamy tylko ostatnio wgrane pliki
  ;


--- -----------------------------------------------------------------------------
-- Widok: silver.v_test_data_offer_levels
-- OPIS: Sprawdzenie dla których ofert nie można było dopasować poziom stanowiska pracy 
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.v_test_data_offer_levels
 AS
 SELECT ofl.id,
    ofl.offer_id,
    ofl.level_name
   FROM silver.offer_levels ofl,
    silver.offers of
  WHERE 1 = 1 AND ofl.offer_id = of.id AND ofl.level_name IS NULL 
  AND ofl.level_name not in (select level_name from gold.d_level)
  AND of.offer_date = (select max(offer_date) from silver.offers) -- sprawdzamy tylko ostatnio wgrane pliki
  ;
  
  
--- -----------------------------------------------------------------------------
-- Widok: silver.v_test_data_offer_modes
-- OPIS: Sprawdzenie dla których ofert nie można było dopasować trybu pracy 
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.v_test_data_offer_modes
 AS
 SELECT ofm.id,
    ofm.offer_id,
    ofm.mode_name
   FROM silver.offer_modes ofm,
    silver.offers of
  WHERE 1 = 1 AND ofm.offer_id = of.id 
  AND (COALESCE(ofm.mode_name, 'BRAK'::text) <> ALL (ARRAY['Hybrid'::text, 'Office'::text, 'Remote'::text, 'Mobile'::text])) 
  AND ofm.mode_name not in (select mode_name from gold.d_mode)
  AND of.offer_date = (select max(offer_date) from silver.offers) -- sprawdzamy tylko ostatnio wgrane pliki
  ;
  
  

--- -----------------------------------------------------------------------------
-- Widok: silver.v_test_data_offer_salaries
-- OPIS: Sprawdzenie dla których ofert nie można było dopasować rodzaj kontraktu oraz gdzie nie zostały wgrane dane do wymaganych kolumn
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.v_test_data_offer_salaries
 AS
 SELECT ofs.id,
    ofs.offer_id,
    of.url,
    ofs.contract_type,
    ofs.salary_min,
    ofs.salary_max,
    ofs.currency,
    ofs.period,
    ofs.salary_type
   FROM silver.offer_salaries ofs,
    silver.offers of
  WHERE 
  	1 = 1 	
  	AND ofs.offer_id = of.id 
  	AND of.offer_date = (( SELECT max(offers.offer_date) AS max FROM silver.offers)) 
	AND (ofs.contract_type IS NULL OR ofs.salary_min IS NULL OR ofs.salary_max IS NULL OR ofs.currency IS NULL OR ofs.period IS NULL OR ofs.salary_type IS NULL OR (ofs.contract_type NOT IN ( SELECT d_contract.contract_name FROM gold.d_contract)))
	;




--- -----------------------------------------------------------------------------
-- Widok: silver.v_test_data_offer_schedules
-- OPIS: Sprawdzenie dla których ofert nie można było dopasować trybu czasu pracy 
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.v_test_data_offer_schedules
 AS
 SELECT ofs.id,
    ofs.offer_id,
    ofs.schedule_name
   FROM silver.offer_schedules ofs,
    silver.offers of
  WHERE 1 = 1 AND ofs.offer_id = of.id AND ofs.schedule_name IS NULL
  AND of.offer_date = (select max(offer_date) from silver.offers) -- sprawdzamy tylko ostatnio wgrane pliki
  ;



--- -----------------------------------------------------------------------------
-- Widok: silver.v_test_data_offer_specs
-- OPIS: Sprawdzenie, które specjalizacje z tabeli silver nie pasują do aliasu danego ustandaryzowanej specjalizacji z tabeli gold (dim) 
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.v_test_data_offer_specs
 AS
 SELECT DISTINCT os.offer_id,
    of.offer_date,
    string_agg(os.specialization_name, ', '::text) AS spec
   FROM silver.offer_specs os
     JOIN silver.offers of ON os.offer_id = of.id
  WHERE NOT (EXISTS ( SELECT 1
           FROM gold.d_specs ds
          WHERE ds.spec_aliases @> to_jsonb(os.specialization_name))) AND of.offer_date = (( SELECT max(offers.offer_date) AS max
           FROM silver.offers))
  GROUP BY os.offer_id, of.offer_date
  ORDER BY of.offer_date DESC;
  
  


--- -----------------------------------------------------------------------------
-- Widok: silver.v_test_data_offer_tech
-- OPIS: Sprawdzenie, które technologie z tabeli silver nie pasują do pattern danego ustandaryzowanej technologii z tabeli gold (dim) 
--- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW silver.v_test_data_offer_tech
 AS
 SELECT DISTINCT ot.technology_name,
    count(*) AS cnt
   FROM silver.offer_technologies ot,
    silver.offers of
  WHERE NOT (EXISTS ( SELECT 1
           FROM gold.d_technology dt
          WHERE (EXISTS ( SELECT 1
                   FROM jsonb_array_elements_text(dt.like_patterns) pattern(value)
                  WHERE lower(ot.technology_name) ~~ pattern.value)))) AND ot.offer_id = of.id 
				  AND of.offer_date = (select max(offer_date) from silver.offers) -- sprawdzamy tylko ostatnio wgrane pliki
  GROUP BY ot.technology_name
  ORDER BY (count(*)) DESC;

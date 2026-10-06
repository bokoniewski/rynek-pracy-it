-- =============================================================================
-- SKRYPT: Widoki pomocnicze do sprawdzenia poprawności wgrywanych danych – warstwa GOLD
-- PROJEKT: Project_job
-- OPIS: Gotowy create view dla warstwy GOLD
-- KOLEJNOŚĆ WYKONANIA: 8
-- ZALEŻNOŚCI: 01_schemas.sql, 02_bronze_tables.sql, 03_silver_tables.sql, 04_gold_tables.sql
-- =============================================================================





--- -----------------------------------------------------------------------------
-- Widok: gold.v_f_day_offers_rejected 
-- OPIS:  sprawdzenie jakie oferty zostały pominiete podczas wgrywania danych do tabeli faktów "gold.f_day_offers"
-- UWAGA: POMIJAM w sekcji Raporotwej (nie potrzebuje, ale kod zostawiam)
--- -----------------------------------------------------------------------------
create or replace view gold.v_f_day_offers_rejected as
WITH base_offers AS (
    SELECT
        o.id            AS offer_id,
        dd.d_date_id,
        o.source_offer_id,
        o.portal_id,
        o.url,
        o.title,
        o.company_name,
        o.offer_date
    FROM silver.offers o
    INNER JOIN gold.D_DATE dd
        ON dd.date_actual = o.offer_date
    WHERE o.offer_date = (select max(offer_date) from silver.offers) -- sprawdzamy tylko ostatnio wgrane pliki
),

offer_spec AS (
    SELECT DISTINCT ON (os.offer_id)
        os.offer_id,
        ds.d_spec_id
    FROM silver.offer_specs os
    INNER JOIN gold.D_SPECS ds
        ON ds.spec_aliases @> to_jsonb(os.specialization_name)
    ORDER BY os.offer_id, ds.priority ASC
),

offer_level AS (
    SELECT DISTINCT ol.offer_id, dl.d_level_id
    FROM silver.offer_levels ol
    INNER JOIN gold.D_LEVEL dl ON dl.level_name = ol.level_name
),

offer_mode AS (
    SELECT DISTINCT om.offer_id, dm.d_mode_id
    FROM silver.offer_modes om
    INNER JOIN gold.D_MODE dm ON dm.mode_name = CASE om.mode_name
        WHEN 'Remote' THEN 'Zdalnie'
        WHEN 'Hybrid' THEN 'Hybrydowo'
        WHEN 'Office' THEN 'Biuro'
        WHEN 'Mobile' THEN 'W terenie'
    END
),

offer_contract AS (
    SELECT DISTINCT oc.offer_id, dc.d_contract_id
    FROM silver.offer_contracts oc
    INNER JOIN gold.D_CONTRACT dc ON dc.contract_name = oc.contract_name
),

flags AS (
    SELECT
        bo.offer_id,
        bo.d_date_id,
        bo.source_offer_id,
        bo.portal_id,
        bo.url,
        bo.title,
        bo.company_name,
        bo.offer_date,

        -- protocol (portal_id=4) nie ma specs — nie flagujemy
		-- pracuj (portal_id=1) gdy specjalizacja jest N/A
        CASE
            WHEN bo.portal_id = 4       THEN FALSE
			WHEN bo.portal_id = 1 and stg_pr.specialization = 'N/A' THEN FALSE
            WHEN os.offer_id IS NULL    THEN TRUE
            ELSE FALSE
        END                             AS missing_spec,
		
        CASE WHEN ol.offer_id IS NULL   THEN TRUE ELSE FALSE END AS missing_level,
        CASE WHEN om.offer_id IS NULL   THEN TRUE ELSE FALSE END AS missing_mode,
        
		-- nofluf (portal_id=3) gdy salary jest N/A bo tylko z tego portalu biore rodzaj kontraktu
		CASE 
			WHEN bo.portal_id = 3 and NOT EXISTS (
			        SELECT 1
			        FROM jsonb_array_elements_text(stg_fl.salary_info) AS item
			        WHERE item ~ '[0-9]'
			    ) 
				THEN FALSE
			when bo.portal_id = 2 AND  NOT EXISTS (
			        SELECT 1
			        FROM string_to_table(stg_jo.job_contract, ',') AS item
			        WHERE lower(item) != 'any'
			    ) THEN FALSE
			WHEN oc.offer_id IS NULL   THEN TRUE ELSE FALSE END AS missing_contract

    FROM base_offers bo
    LEFT JOIN offer_spec     os ON os.offer_id = bo.offer_id
    LEFT JOIN offer_level    ol ON ol.offer_id = bo.offer_id
    LEFT JOIN offer_mode     om ON om.offer_id = bo.offer_id
    LEFT JOIN offer_contract oc ON oc.offer_id = bo.offer_id
	LEFT JOIN silver.stg_pracuj stg_pr ON stg_pr.source_offer_id = bo.source_offer_id and stg_pr.offer_date = bo.offer_date
	LEFT JOIN silver.stg_joinit stg_jo ON stg_jo.source_offer_id = bo.source_offer_id and stg_jo.offer_date = bo.offer_date
	LEFT JOIN silver.stg_nofluff stg_fl ON stg_fl.source_offer_id = bo.source_offer_id and stg_fl.offer_date = bo.offer_date
	LEFT JOIN silver.stg_protocol stg_pt ON stg_pt.source_offer_id = bo.source_offer_id and stg_pt.offer_date = bo.offer_date
)

-- Pokaż tylko oferty które mają co najmniej jeden brakujący wymiar
SELECT distinct *
FROM flags
WHERE TRUE IN (missing_spec, missing_level, missing_mode, missing_contract) 
;






--- -----------------------------------------------------------------------------
-- Widok: gold.v_f_day_offers_loc_rejected
-- OPIS:  sprawdzenie jakie oferty zostały pominiete podczas wgrywania danych do tabeli faktów "gold.f_day_offers_loc"
-- UWAGA: POMIJAM w sekcji Raporotwej (nie potrzebuje, ale kod zostawiam)
--- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.v_f_day_offers_loc_rejected AS

WITH base_offers AS (
    SELECT
        o.id            AS offer_id,
        dd.d_date_id,
        o.source_offer_id,
        o.portal_id,
        o.url,
        o.title,
        o.company_name,
        o.offer_date
    FROM silver.offers o
    INNER JOIN gold.D_DATE dd
        ON dd.date_actual = o.offer_date
    WHERE o.offer_date = (SELECT MAX(offer_date) FROM silver.offers)
),

offer_spec AS (
    SELECT DISTINCT ON (os.offer_id)
        os.offer_id,
        ds.d_spec_id
    FROM silver.offer_specs os
    INNER JOIN gold.D_SPECS ds
        ON ds.spec_aliases @> to_jsonb(os.specialization_name)
    ORDER BY os.offer_id, ds.priority ASC
),

offer_level AS (
    SELECT DISTINCT ol.offer_id, dl.d_level_id
    FROM silver.offer_levels ol
    INNER JOIN gold.D_LEVEL dl ON dl.level_name = ol.level_name
),

offer_mode AS (
    SELECT DISTINCT om.offer_id, dm.d_mode_id, dm.mode_name
    FROM silver.offer_modes om
    INNER JOIN gold.D_MODE dm ON dm.mode_name = CASE om.mode_name
        WHEN 'Remote' THEN 'Zdalnie'
        WHEN 'Hybrid' THEN 'Hybrydowo'
        WHEN 'Office' THEN 'Biuro'
        WHEN 'Mobile' THEN 'W terenie'
    END
),

offer_contract AS (
    SELECT DISTINCT oc.offer_id, dc.d_contract_id
    FROM silver.offer_contracts oc
    INNER JOIN gold.D_CONTRACT dc ON dc.contract_name = oc.contract_name
),

offer_location AS (
    SELECT DISTINCT ol.offer_id, dl.d_location_id
    FROM silver.offer_locations ol
    INNER JOIN gold.D_LOCATION dl
        ON EXISTS (
            SELECT 1
            FROM jsonb_array_elements_text(dl.like_patterns) AS pattern
            WHERE translate(lower(trim(ol.city)), 'ąćęłńóśźż', 'acelnoszz') ~~ pattern
        )
),

flags AS (
    SELECT
        bo.offer_id,
        bo.d_date_id,
        bo.source_offer_id,
        bo.portal_id,
        bo.url,
        bo.title,
        bo.company_name,
        bo.offer_date,

        CASE
            WHEN bo.portal_id = 4                               THEN FALSE
            WHEN bo.portal_id = 1 AND stg_pr.specialization = 'N/A' THEN FALSE
            WHEN os.offer_id IS NULL                            THEN TRUE
            ELSE FALSE
        END                                                     AS missing_spec,

        CASE WHEN ol.offer_id IS NULL THEN TRUE ELSE FALSE END  AS missing_level,

        -- dla loc tylko Hybrid/Office — Remote/Mobile są ok bo nie mają lokalizacji
        CASE
			WHEN om.mode_name NOT IN ('Hybrydowo', 'Biuro') THEN FALSE
			WHEN om.offer_id IS NULL THEN TRUE ELSE FALSE END  AS missing_mode,

        CASE
            WHEN bo.portal_id = 3 AND NOT EXISTS (
                SELECT 1
                FROM jsonb_array_elements_text(stg_fl.salary_info) AS item
                WHERE item ~ '[0-9]'
            ) THEN FALSE
            WHEN bo.portal_id = 2 AND NOT EXISTS (
                SELECT 1
                FROM string_to_table(stg_jo.job_contract, ',') AS item
                WHERE lower(item) != 'any'
            ) THEN FALSE
            WHEN oc.offer_id IS NULL THEN TRUE ELSE FALSE
        END                                                     AS missing_contract,

        CASE WHEN loc.offer_id IS NULL THEN TRUE ELSE FALSE END AS missing_location

    FROM base_offers bo
    LEFT JOIN offer_spec     os  ON os.offer_id  = bo.offer_id
    LEFT JOIN offer_level    ol  ON ol.offer_id  = bo.offer_id
    LEFT JOIN offer_mode     om  ON om.offer_id  = bo.offer_id
    LEFT JOIN offer_contract oc  ON oc.offer_id  = bo.offer_id
    LEFT JOIN offer_location loc ON loc.offer_id = bo.offer_id
    LEFT JOIN silver.stg_pracuj  stg_pr ON stg_pr.source_offer_id = bo.source_offer_id AND stg_pr.offer_date = bo.offer_date
    LEFT JOIN silver.stg_joinit  stg_jo ON stg_jo.source_offer_id = bo.source_offer_id AND stg_jo.offer_date = bo.offer_date
    LEFT JOIN silver.stg_nofluff stg_fl ON stg_fl.source_offer_id = bo.source_offer_id AND stg_fl.offer_date = bo.offer_date
)

SELECT DISTINCT *
FROM flags
WHERE TRUE IN (missing_spec, missing_level, missing_mode, missing_contract, missing_location)
order by missing_spec desc, missing_level desc, missing_mode desc, missing_contract desc, missing_location desc
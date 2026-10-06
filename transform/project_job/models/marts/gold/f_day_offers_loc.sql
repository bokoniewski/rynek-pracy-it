-- models/marts/gold/f_day_offers_loc.sql
-- Uruchomienie: dbt run --profiles-dir . --select f_day_offers_loc

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='d_date_id'
) }}

WITH base_offers AS (
    SELECT
        o.offer_id,
        dd.d_date_id
    FROM {{ ref('stg_gold_offers') }} o
    INNER JOIN {{ source('gold', 'd_date') }} dd
        ON dd.date_actual = o.offer_date
),

offer_spec AS (
    SELECT DISTINCT ON (os.offer_id)
        os.offer_id,
        ds.d_spec_id,
        COUNT(*) AS match_count
    FROM {{ source('silver', 'offer_specs') }} os
    INNER JOIN base_offers bo ON bo.offer_id = os.offer_id
    INNER JOIN {{ source('gold', 'd_specs') }} ds
        ON ds.spec_aliases @> to_jsonb(os.specialization_name)
    GROUP BY os.offer_id, ds.d_spec_id, ds.priority
    ORDER BY os.offer_id, COUNT(*) DESC, ds.priority ASC
),

offer_level AS (
    SELECT DISTINCT ol.offer_id, dl.d_level_id
    FROM {{ source('silver', 'offer_levels') }} ol
    INNER JOIN base_offers bo ON bo.offer_id = ol.offer_id
    INNER JOIN {{ source('gold', 'd_level') }} dl
        ON dl.level_name = ol.level_name
),

offer_mode AS (
    -- tylko Hybrid i Office — Remote i Mobile nie mają fizycznej lokalizacji
    SELECT DISTINCT om.offer_id, dm.d_mode_id
    FROM {{ source('silver', 'offer_modes') }} om
    INNER JOIN base_offers bo ON bo.offer_id = om.offer_id
    INNER JOIN {{ source('gold', 'd_mode') }} dm
        ON dm.mode_name = CASE om.mode_name
            WHEN 'Hybrid' THEN 'Hybrydowo'
            WHEN 'Office' THEN 'Biuro'
        END
    WHERE om.mode_name IN ('Hybrid', 'Office')
),

offer_contract AS (
    SELECT DISTINCT oc.offer_id, dc.d_contract_id
    FROM {{ source('silver', 'offer_contracts') }} oc
    INNER JOIN base_offers bo ON bo.offer_id = oc.offer_id
    INNER JOIN {{ source('gold', 'd_contract') }} dc
        ON dc.contract_name = oc.contract_name
),

offer_location AS (
    SELECT DISTINCT ol.offer_id, dl.d_location_id
    FROM {{ source('silver', 'offer_locations') }} ol
    INNER JOIN base_offers bo ON bo.offer_id = ol.offer_id
    INNER JOIN {{ source('gold', 'd_location') }} dl
        ON EXISTS (
            SELECT 1
            FROM jsonb_array_elements_text(dl.like_patterns) AS pattern
            WHERE translate(lower(trim(ol.city)), 'ąćęłńóśźż', 'acelnoszz') ~~ pattern
        )
)

SELECT
    bo.d_date_id,
    ol.d_location_id,
    os.d_spec_id,
    lv.d_level_id,
    om.d_mode_id,
    oc.d_contract_id,
    COUNT(*)            AS total_offers
FROM base_offers bo
INNER JOIN offer_spec       os ON os.offer_id = bo.offer_id
INNER JOIN offer_level      lv ON lv.offer_id = bo.offer_id
INNER JOIN offer_mode       om ON om.offer_id = bo.offer_id
INNER JOIN offer_contract   oc ON oc.offer_id = bo.offer_id
INNER JOIN offer_location   ol ON ol.offer_id = bo.offer_id
GROUP BY
    bo.d_date_id,
    ol.d_location_id,
    os.d_spec_id,
    lv.d_level_id,
    om.d_mode_id,
    oc.d_contract_id
-- models/gold/f_day_offers.sql
-- Strategia: DELETE + INSERT per dzień (d_date_id)
-- Wywołanie: dbt run --profiles-dir . --select f_day_offers --vars '{"FILE_DATE": "2026-04-19"}'

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key		='d_date_id'
) }}


with base_offers AS (
    -- Punkt wejścia z filtrem daty — ograniczamy zbiór od razu
    SELECT
        o.offer_id,
        dd.d_date_id
    FROM {{ ref('stg_gold_offers') }} o
    INNER JOIN {{ source('gold', 'd_date') }} dd
        ON dd.date_actual = o.offer_date
),

offer_spec AS (
    -- Jedna specjalizacja per oferta — najwyższy priorytet z D_SPECS
    SELECT DISTINCT ON (os.offer_id)
        os.offer_id,
        ds.d_spec_id
    FROM {{ source('silver', 'offer_specs') }} os
    INNER JOIN base_offers bo
        ON bo.offer_id = os.offer_id
    INNER JOIN {{ source('gold', 'd_specs') }} ds
        ON ds.spec_aliases @> to_jsonb(os.specialization_name)
    ORDER BY os.offer_id, ds.priority ASC
),

offer_level AS (
    SELECT
        ol.offer_id,
        dl.d_level_id
    FROM {{ source('silver', 'offer_levels') }} ol
    INNER JOIN base_offers bo
        ON bo.offer_id = ol.offer_id
    INNER JOIN {{ source('gold', 'd_level') }} dl
        ON dl.level_name = ol.level_name
),

offer_mode AS (
    SELECT
        om.offer_id,
        dm.d_mode_id
    FROM {{ source('silver', 'offer_modes') }} om
    INNER JOIN base_offers bo
        ON bo.offer_id = om.offer_id
    INNER JOIN {{ source('gold', 'd_mode') }} dm
        ON dm.mode_name = CASE om.mode_name
            WHEN 'Remote' THEN 'Zdalnie'
            WHEN 'Hybrid' THEN 'Hybrydowo'
            WHEN 'Office' THEN 'Biuro'
            WHEN 'Mobile' THEN 'W terenie'
        END
),

offer_contract AS (
    SELECT
        oc.offer_id,
        dc.d_contract_id
    FROM {{ source('silver', 'offer_contracts') }} oc
    INNER JOIN base_offers bo
        ON bo.offer_id = oc.offer_id
    INNER JOIN {{ source('gold', 'd_contract') }} dc
        ON dc.contract_name = oc.contract_name
)

SELECT
    bo.d_date_id,
    os.d_spec_id,
    ol.d_level_id,
    om.d_mode_id,
    oc.d_contract_id,
    COUNT(DISTINCT bo.offer_id)     AS total_offers

FROM base_offers bo
INNER JOIN offer_spec os        ON os.offer_id = bo.offer_id
INNER JOIN offer_level ol       ON ol.offer_id = bo.offer_id
INNER JOIN offer_mode om        ON om.offer_id = bo.offer_id
INNER JOIN offer_contract oc    ON oc.offer_id = bo.offer_id

GROUP BY
    bo.d_date_id,
    os.d_spec_id,
    ol.d_level_id,
    om.d_mode_id,
    oc.d_contract_id
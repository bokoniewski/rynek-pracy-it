-- models/marts/gold/f_day_salaries.sql
-- Uruchomienie: dbt run --profiles-dir . --select f_day_salaries

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
    SELECT DISTINCT om.offer_id, dm.d_mode_id
    FROM {{ source('silver', 'offer_modes') }} om
    INNER JOIN base_offers bo ON bo.offer_id = om.offer_id
    INNER JOIN {{ source('gold', 'd_mode') }} dm
        ON dm.mode_name = CASE om.mode_name
            WHEN 'Remote' THEN 'Zdalnie'
            WHEN 'Hybrid' THEN 'Hybrydowo'
            WHEN 'Office' THEN 'Biuro'
            WHEN 'Mobile' THEN 'W terenie'
        END
),

salaries_normalized AS (
    SELECT
        os.offer_id,
        dc.d_contract_id,
        -- normalizacja do stawki miesięcznej PLN
        CASE os.period
            WHEN 'MONTHLY'   THEN os.salary_min
            WHEN 'ANNUALLY'  THEN os.salary_min / 12
            WHEN 'DAILY'     THEN os.salary_min * 20
            WHEN 'HOURLY'    THEN os.salary_min * 8 * 20
        END                                     AS salary_min_monthly,
        CASE os.period
            WHEN 'MONTHLY'   THEN os.salary_max
            WHEN 'ANNUALLY'  THEN os.salary_max / 12
            WHEN 'DAILY'     THEN os.salary_max * 20
            WHEN 'HOURLY'    THEN os.salary_max * 8 * 20
        END                                     AS salary_max_monthly
    FROM {{ source('silver', 'offer_salaries') }} os
    INNER JOIN base_offers bo ON bo.offer_id = os.offer_id
    INNER JOIN {{ source('gold', 'd_contract') }} dc
        ON dc.contract_name = os.contract_type
    WHERE os.currency = 'PLN'
      AND os.salary_min IS NOT NULL
      AND os.salary_max IS NOT NULL
      AND os.period IN ('MONTHLY', 'ANNUALLY', 'DAILY', 'HOURLY')
)

SELECT
    bo.d_date_id,
    os.d_spec_id,
    lv.d_level_id,
    om.d_mode_id,
    sn.d_contract_id,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sn.salary_min_monthly)) AS salary_min_median,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sn.salary_max_monthly)) AS salary_max_median,
    COUNT(*)                                                             AS offer_count
FROM salaries_normalized sn
INNER JOIN base_offers bo   ON bo.offer_id  = sn.offer_id
INNER JOIN offer_spec  os   ON os.offer_id  = sn.offer_id
INNER JOIN offer_level lv   ON lv.offer_id  = sn.offer_id
INNER JOIN offer_mode  om   ON om.offer_id  = sn.offer_id
GROUP BY
    bo.d_date_id,
    os.d_spec_id,
    lv.d_level_id,
    om.d_mode_id,
    sn.d_contract_id
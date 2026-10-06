-- models/marts/gold/f_month_salaries_agg.sql
-- Uruchomienie: dbt run --profiles-dir . --select f_month_salaries_agg

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['year', 'month']
) }}

WITH base_month AS (
    SELECT DISTINCT
        dd.year,
        dd.month
    FROM {{ ref('stg_gold_offers') }} o
    INNER JOIN {{ source('gold', 'd_date') }} dd
        ON dd.date_actual = o.offer_date
)

SELECT
    dd.year,
    dd.month,
    f.d_spec_id,
    f.d_level_id,
    f.d_mode_id,
    f.d_contract_id,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.salary_min_median)) AS salary_min_median,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.salary_max_median)) AS salary_max_median,
    SUM(f.offer_count)      AS offer_count
FROM {{ source('gold', 'f_day_salaries') }} f
INNER JOIN {{ source('gold', 'd_date') }} dd
    ON dd.d_date_id = f.d_date_id
INNER JOIN base_month bm
    ON bm.year  = dd.year
    AND bm.month = dd.month
GROUP BY
    dd.year,
    dd.month,
    f.d_spec_id,
    f.d_level_id,
    f.d_mode_id,
    f.d_contract_id

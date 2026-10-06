-- models/marts/gold/f_year_salaries_agg.sql
-- Uruchomienie: dbt run --profiles-dir . --select f_year_salaries_agg

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='year'
) }}

WITH base_year AS (
    SELECT DISTINCT
        dd.year
    FROM {{ ref('stg_gold_offers') }} o
    INNER JOIN {{ source('gold', 'd_date') }} dd
        ON dd.date_actual = o.offer_date
)

SELECT
    f.year,
    f.d_spec_id,
    f.d_level_id,
    f.d_mode_id,
    f.d_contract_id,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.salary_min_median)) AS salary_min_median,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.salary_max_median)) AS salary_max_median,
    SUM(f.offer_count)      AS offer_count
FROM {{ source('gold', 'f_month_salaries_agg') }} f
INNER JOIN base_year byr
    ON byr.year = f.year
GROUP BY
    f.year,
    f.d_spec_id,
    f.d_level_id,
    f.d_mode_id,
    f.d_contract_id
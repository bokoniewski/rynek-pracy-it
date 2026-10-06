-- models/marts/gold/f_year_offers_loc_agg.sql
-- Uruchomienie: dbt run --profiles-dir . --select f_year_offers_loc_agg

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
    f.d_location_id,
    f.d_spec_id,
    f.d_level_id,
    f.d_mode_id,
    f.d_contract_id,
    SUM(f.total_offers)     AS total_offers
FROM {{ source('gold', 'f_month_offers_loc_agg') }} f
INNER JOIN base_year byr
    ON byr.year = f.year
GROUP BY
    f.year,
    f.d_location_id,
    f.d_spec_id,
    f.d_level_id,
    f.d_mode_id,
    f.d_contract_id
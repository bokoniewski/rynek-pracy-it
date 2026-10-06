-- models/marts/gold/f_month_offers_agg.sql
-- Uruchomienie: dbt run --profiles-dir . --select f_month_offers_agg

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['year', 'month']
) }}

WITH base_month AS (
    -- Pobierz year+month z widoku staging — to steruje którym miesiącem operujemy
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
    SUM(f.total_offers)     AS total_offers
FROM {{ source('gold', 'f_day_offers') }} f
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
-- models/marts/gold/f_day_offers_benefit.sql
-- Uruchomienie: dbt run --profiles-dir . --select f_day_offers_benefit

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

offer_benefit AS (
    SELECT
        bo.d_date_id,
        bo.offer_id,
        db.d_benefit_id
    FROM {{ source('silver', 'offer_benefits') }} ob
    INNER JOIN base_offers bo
        ON bo.offer_id = ob.offer_id
    INNER JOIN {{ source('gold', 'd_benefit') }}  db
        ON EXISTS (
            SELECT 1
            FROM jsonb_array_elements_text(db.like_patterns) AS pattern
            WHERE LOWER(ob.benefit_name) ~~ pattern
        )
)

SELECT
    d_date_id,
    d_benefit_id,
    COUNT(*)            AS total_offers
FROM offer_benefit
GROUP BY
    d_date_id,
    d_benefit_id
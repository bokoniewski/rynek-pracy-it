-- models/marts/gold/f_day_offers_technology.sql
-- Uruchomienie: dbt run --profiles-dir . --select f_day_offers_technology

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

offer_technology AS (
    SELECT
        bo.d_date_id,
        bo.offer_id,
        dt.d_tech_id,
        drt.d_req_type_id
    FROM {{ source('silver', 'offer_technologies') }} ot
    INNER JOIN base_offers bo
        ON bo.offer_id = ot.offer_id
    INNER JOIN {{ source('silver', 'def_requirement_type') }} srt
        ON srt.id = ot.requirement_type_id
    INNER JOIN {{ source('gold', 'd_requirement_type') }} drt
        ON drt.requirement_type_name = srt.requirement_type_name
    INNER JOIN {{ source('gold', 'd_technology') }} dt
        ON EXISTS (
            SELECT 1
            FROM jsonb_array_elements_text(dt.like_patterns) AS pattern
            WHERE LOWER(ot.technology_name) ~~ pattern
        )
)

SELECT
    ot.d_date_id,
    ot.d_tech_id                AS d_technology_id,
    ot.d_req_type_id,
    os.d_spec_id,
    COUNT(*)                    AS total_offers
FROM offer_technology ot
INNER JOIN offer_spec os ON os.offer_id = ot.offer_id
GROUP BY
    ot.d_date_id,
    ot.d_tech_id,
    ot.d_req_type_id,
    os.d_spec_id
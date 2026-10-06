-- models/marts/silver/silver_offer_modes.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_modes
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_modes --vars "{\"portals\": [\"pracuj\"]}"

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_modes',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}

SELECT
    nextval(pg_get_serial_sequence('silver.offer_modes', 'id'))::integer AS id,
    o.id        AS offer_id,
    m.mode_name

FROM {{ ref('int_all__offer_modes') }} AS m
INNER JOIN {{ source('silver', 'offers') }} AS o
    ON  m.bronze_file_id  = o.bronze_file_id
    AND m.offer_date      = o.offer_date
    AND m.source_offer_id = o.source_offer_id

WHERE m.portal IN ({{ "'" + portals | join("','") + "'" }})
-- models/marts/silver/silver_offer_locations.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_locations
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_locations --vars "{\"portals\": [\"pracuj\"]}"

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_locations',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}

SELECT
    nextval(pg_get_serial_sequence('silver.offer_locations', 'id'))::integer AS id,
    o.id        AS offer_id,
    l.city,
    l.region,
    l.country

FROM {{ ref('int_all__offer_locations') }} AS l
INNER JOIN {{ source('silver', 'offers') }} AS o
    ON  l.bronze_file_id  = o.bronze_file_id
    AND l.offer_date      = o.offer_date
    AND l.source_offer_id = o.source_offer_id

WHERE l.portal IN ({{ "'" + portals | join("','") + "'" }})
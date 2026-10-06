-- models/marts/silver/silver_offer_specs.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_specs
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_specs --vars "{\"portals\": [\"pracuj\"]}"

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_specs',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}

SELECT
    nextval(pg_get_serial_sequence('silver.offer_specs', 'id'))::integer AS id,
    o.id                    AS offer_id,
    s.specialization_name

FROM {{ ref('int_all__offer_specs') }} AS s
INNER JOIN {{ source('silver', 'offers') }} AS o
    ON  s.bronze_file_id  = o.bronze_file_id
    AND s.offer_date      = o.offer_date
    AND s.source_offer_id = o.source_offer_id

WHERE s.portal IN ({{ "'" + portals | join("','") + "'" }})
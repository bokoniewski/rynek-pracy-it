-- models/marts/silver/silver_offer_technologies.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_technologies
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_technologies --vars "{\"portals\": [\"pracuj\"]}"

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_technologies',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}

SELECT
    nextval(pg_get_serial_sequence('silver.offer_technologies', 'id'))::integer AS id,
    o.id                AS offer_id,
    t.technology_name,
    CASE
        WHEN t.requirement_type = 'wymagane'    THEN 1
        WHEN t.requirement_type = 'opcjonalne'  THEN 2
    END                 AS requirement_type_id

FROM {{ ref('int_all__offer_technologies') }} AS t
INNER JOIN {{ source('silver', 'offers') }} AS o
    ON  t.bronze_file_id  = o.bronze_file_id
    AND t.offer_date      = o.offer_date
    AND t.source_offer_id = o.source_offer_id

WHERE t.portal IN ({{ "'" + portals | join("','") + "'" }})
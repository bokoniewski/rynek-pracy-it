-- models/marts/silver/silver_offer_benefits.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_benefits
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_benefits --vars "{\"portals\": [\"pracuj\"]}"

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_benefits',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}

SELECT
    nextval(pg_get_serial_sequence('silver.offer_benefits', 'id'))::integer AS id,
    o.id            AS offer_id,
    b.benefit_name

FROM {{ ref('int_all__offer_benefits') }} AS b
INNER JOIN {{ source('silver', 'offers') }} AS o
    ON  b.bronze_file_id  = o.bronze_file_id
    AND b.offer_date      = o.offer_date
    AND b.source_offer_id = o.source_offer_id

WHERE b.portal IN ({{ "'" + portals | join("','") + "'" }})
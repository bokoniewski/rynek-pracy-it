-- models/marts/silver/silver_offer_requirements.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_requirements
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_requirements --vars "{\"portals\": [\"pracuj\"]}"

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_requirements',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}

SELECT
    nextval(pg_get_serial_sequence('silver.offer_requirements', 'id'))::integer AS id,
    o.id            															AS offer_id,
    trim(replace(b.req_name,'•', ''))     										AS requirement_text,
	b.req_type_id																AS requirement_type_id

FROM {{ ref('int_all__offer_requirements') }} AS b
INNER JOIN {{ source('silver', 'offers') }} AS o
    ON  b.bronze_file_id  = o.bronze_file_id
    AND b.offer_date      = o.offer_date
    AND b.source_offer_id = o.source_offer_id

WHERE b.portal IN ({{ "'" + portals | join("','") + "'" }})
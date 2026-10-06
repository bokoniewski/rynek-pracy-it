-- models/marts/silver/silver_offer_responsibilities.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_responsibilities
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_responsibilities --vars "{\"portals\": [\"pracuj\"]}"
-- dla requirement_type_id zawsze 1 jako wymagane, póki co nie mam portalu który dzieli obowiązki na wymagane i opcjonalne

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_responsibilities',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}

SELECT
    nextval(pg_get_serial_sequence('silver.offer_responsibilities', 'id'))::integer AS id,
    o.id            AS offer_id,
    b.resp_name     AS responsibility_text,
	1::integer		AS requirement_type_id

FROM {{ ref('int_all__offer_responsibilities') }} AS b
INNER JOIN {{ source('silver', 'offers') }} AS o
    ON  b.bronze_file_id  = o.bronze_file_id
    AND b.offer_date      = o.offer_date
    AND b.source_offer_id = o.source_offer_id

WHERE b.portal IN ({{ "'" + portals | join("','") + "'" }})
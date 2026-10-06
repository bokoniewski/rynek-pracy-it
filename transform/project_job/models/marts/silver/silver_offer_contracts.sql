-- models/marts/silver/silver_offer_contracts.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_contracts
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_contracts --vars "{\"portals\": [\"pracuj\"]}"

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_contracts',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}

SELECT
    nextval(pg_get_serial_sequence('silver.offer_contracts', 'id'))::integer AS id,
    o.id            AS offer_id,
    c.contract_name

FROM {{ ref('int_all__offer_contracts') }} AS c
INNER JOIN {{ source('silver', 'offers') }} AS o
    ON  c.bronze_file_id  = o.bronze_file_id
    AND c.offer_date      = o.offer_date
    AND c.source_offer_id = o.source_offer_id

WHERE c.portal IN ({{ "'" + portals | join("','") + "'" }})
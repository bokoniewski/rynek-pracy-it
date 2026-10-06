-- models/marts/silver/silver_offer_salaries.sql
-- CMD: dbt run --profiles-dir . --select silver_offer_salaries
-- OPCJONALNIE: dbt run --profiles-dir . --select silver_offer_salaries --vars "{\"portals\": [\"pracuj\"]}"

{{
    config(
        materialized = 'incremental',
        alias        = 'offer_salaries',
		incremental_strategy='delete+insert',
		unique_key   = 'offer_id'
    )
}}

{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}
{% set ns = namespace(first=true) %}

{% for portal in portals %}

    {% if not ns.first %} UNION ALL {% endif %}

    SELECT
        nextval(pg_get_serial_sequence('silver.offer_salaries', 'id'))::integer AS id,
        o.id            AS offer_id,
        s.contract_type,
        s.salary_min,
        s.salary_max,
        s.currency,
        s.period,
        s.salary_type
    FROM {{ ref('int_' ~ portal ~ '__offer_salaries') }} AS s
    INNER JOIN {{ source('silver', 'offers') }} AS o
        ON  s.bronze_file_id  = o.bronze_file_id
        AND s.offer_date      = o.offer_date
        AND s.source_offer_id = o.source_offer_id

    {% set ns.first = false %}

{% endfor %}
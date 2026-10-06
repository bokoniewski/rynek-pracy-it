-- models/marts/silver/silver_offers.sql
-- Oferty → silver.offers
-- UWAGA: delete+insert usuwa istniejace i wgrywa nowe na ich miejsce

-- CMD:
-- dbt run --profiles-dir . --select +silver_offers
-- OPCJONALNIE: vars --> file_date, portals
-- dbt run --profiles-dir . --select +silver_offers --vars "{\"portals\": [\"pracuj\"]}"
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key   = ['offer_date', 'bronze_file_id'],
        alias        = 'offers'
    )
}}


{% set portals = var('portals', ['pracuj', 'joinit', 'nofluff', 'protocol']) %}
{% set ns = namespace(first=true) %}

{% for portal in portals %}

    {% if not ns.first %} UNION ALL {% endif %}

    SELECT
        nextval(pg_get_serial_sequence('silver.offers', 'id'))::integer AS id,
        portal_id,
        bronze_file_id,
        source_offer_id,
        url,
        title,
        company_name,
        offer_date,
        created_at
    FROM {{ ref('int_' ~ portal ~ '__offers') }}

    {% set ns.first = false %}

{% endfor %}


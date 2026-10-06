-- models/gold/stg_gold_offers.sql
-- Wywołanie: dbt run --profiles-dir . --select stg_gold_offers --vars '{"FILE_DATE": "2026-04-19"}'

{{ config(materialized='view') }}

SELECT
    id              	AS offer_id,
    source_offer_id,
    portal_id,
    offer_date,
    title,
    company_name,
    url
FROM {{ source('silver', 'offers') }}
WHERE offer_date = CAST('{{ var("FILE_DATE", "1899-12-30") }}' AS DATE)
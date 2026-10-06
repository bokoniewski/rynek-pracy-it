-- models/intermediate/int_nofluff__offers.sql
-- Przygotowanie rekordów ofert z nofluffjob do załadowania do silver.offers
-- Materialized jako ephemeral — SQL (CTE) dla modelu innego modelu (nie trzyma danych w locie)

{{
    config(
        materialized = 'ephemeral'
    )
}}

WITH stg AS (
    SELECT
        raw_id,
		bronze_file_id,
        loaded_at,
        source_offer_id,
        url,
        TRIM(REGEXP_REPLACE(
			REGEXP_REPLACE(
				title,
				'[\s\(\)]*100%\s*[Rr]emote[\s\(\)]*',  -- usuwa "100% remote" z nawiasami/spacjami
				'',
				'ig'
			),
			'[\s\-|/\\\\]+$',  -- usuwa znaki specjalne na końcu
			''						)) AS title,
        company_name,
        offer_date
    FROM {{ ref('stg_nofluff') }}
),

-- Pobierz portal_id raz
portal AS (
    SELECT id AS portal_id
    FROM {{ source('silver', 'def_portal') }}
    WHERE portal_name = 'nofluff'
)


SELECT
    portal.portal_id,
    stg.bronze_file_id,
    stg.source_offer_id,
    stg.url,
    stg.title,
    stg.company_name,
    stg.offer_date,
    NOW()                                       AS created_at

FROM stg
INNER JOIN portal
    ON TRUE                                     -- cross join — jeden rekord portalu
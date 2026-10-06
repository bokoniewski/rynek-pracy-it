-- models/intermediate/int_joinit__offers.sql
-- Przygotowanie rekordów ofert z thejoinit do załadowania do silver.offers
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
        REGEXP_REPLACE(
			REPLACE(
				NULLIF(TRIM(title), ''),
			'&amp;', '&'),
		'[^\x00-\x7F\xC0-\x024F]', '', 'g') AS title,
        company_name,
        offer_date
    FROM {{ ref('stg_joinit') }}
),

-- Pobierz portal_id raz
portal AS (
    SELECT id AS portal_id
    FROM {{ source('silver', 'def_portal') }}
    WHERE portal_name = 'joinit'
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
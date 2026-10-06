-- tests/silver_offer_specs.sql
-- Testy dla modelu silver_offer_specs
-- Zakres: tylko dane z bieżącego dnia (FILE_DATE)

-- not_null: id
SELECT 'not_null_id' AS test_name, id
FROM {{ ref('silver_offer_specs') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND id IS NULL

UNION ALL

-- not_null: offer_id
SELECT 'not_null_offer_id' AS test_name, id
FROM {{ ref('silver_offer_specs') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id IS NULL

UNION ALL

-- relationships: offer_id -> silver_offers.id
SELECT 'relationships_offer_id' AS test_name, id
FROM {{ ref('silver_offer_specs') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id NOT IN (
    SELECT id FROM {{ ref('silver_offers') }}
)

UNION ALL

-- not_null: specialization_name
SELECT 'not_null_specialization_name' AS test_name, id
FROM {{ ref('silver_offer_specs') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND specialization_name IS NULL

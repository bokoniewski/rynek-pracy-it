-- tests/silver_offer_modes.sql
-- Testy dla modelu silver_offer_modes
-- Zakres: tylko dane z bieżącego dnia (FILE_DATE)

-- not_null: id
SELECT 'not_null_id' AS test_name, id
FROM {{ ref('silver_offer_modes') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND id IS NULL

UNION ALL

-- not_null: offer_id
SELECT 'not_null_offer_id' AS test_name, id
FROM {{ ref('silver_offer_modes') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id IS NULL

UNION ALL

-- relationships: offer_id -> silver_offers.id
SELECT 'relationships_offer_id' AS test_name, id
FROM {{ ref('silver_offer_modes') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id NOT IN (
    SELECT id FROM {{ ref('silver_offers') }}
)

UNION ALL

-- not_null: mode_name
SELECT 'not_null_mode_name' AS test_name, id
FROM {{ ref('silver_offer_modes') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND mode_name IS NULL

UNION ALL

-- accepted_values: mode_name
SELECT 'accepted_values_mode_name' AS test_name, id
FROM {{ ref('silver_offer_modes') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND mode_name IS NOT NULL
AND mode_name NOT IN ('Remote', 'Hybrid', 'Office', 'Mobile', 'N/A')

-- tests/silver_offer_requirements.sql
-- Testy dla modelu silver_offer_requirements
-- Zakres: tylko dane z bieżącego dnia (FILE_DATE)

-- not_null: id
SELECT 'not_null_id' AS test_name, id
FROM {{ ref('silver_offer_requirements') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND id IS NULL

UNION ALL

-- not_null: offer_id
SELECT 'not_null_offer_id' AS test_name, id
FROM {{ ref('silver_offer_requirements') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id IS NULL

UNION ALL

-- relationships: offer_id -> silver_offers.id
SELECT 'relationships_offer_id' AS test_name, id
FROM {{ ref('silver_offer_requirements') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id NOT IN (
    SELECT id FROM {{ ref('silver_offers') }}
)

UNION ALL

-- not_null: requirement_text
SELECT 'not_null_requirement_text' AS test_name, id
FROM {{ ref('silver_offer_requirements') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND requirement_text IS NULL

UNION ALL

-- not_null: requirement_type_id
SELECT 'not_null_requirement_type_id' AS test_name, id
FROM {{ ref('silver_offer_requirements') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND requirement_type_id IS NULL

UNION ALL

-- accepted_values: requirement_type_id (1=wymagane, 2=opcjonalne)
SELECT 'accepted_values_requirement_type_id' AS test_name, id
FROM {{ ref('silver_offer_requirements') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND requirement_type_id IS NOT NULL
AND requirement_type_id NOT IN (1, 2)

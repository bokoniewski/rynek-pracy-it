-- tests/silver_offers.sql
-- Testy dla modelu silver_offers
-- Zakres: tylko dane z bieżącego dnia (FILE_DATE)

-- not_null: id
SELECT 'not_null_id' AS test_name, id
FROM {{ ref('silver_offers') }}
WHERE {{ file_date_filter() }}
AND id IS NULL

UNION ALL

-- unique: id
SELECT 'unique_id' AS test_name, id
FROM {{ ref('silver_offers') }}
WHERE {{ file_date_filter() }}
AND id IN (
    SELECT id
    FROM {{ ref('silver_offers') }}
    WHERE {{ file_date_filter() }}
    GROUP BY id
    HAVING COUNT(*) > 1
)

UNION ALL

-- not_null: portal_id
SELECT 'not_null_portal_id' AS test_name, id
FROM {{ ref('silver_offers') }}
WHERE {{ file_date_filter() }}
AND portal_id IS NULL

UNION ALL

-- not_null: bronze_file_id
SELECT 'not_null_bronze_file_id' AS test_name, id
FROM {{ ref('silver_offers') }}
WHERE {{ file_date_filter() }}
AND bronze_file_id IS NULL

UNION ALL

-- not_null: source_offer_id
SELECT 'not_null_source_offer_id' AS test_name, id
FROM {{ ref('silver_offers') }}
WHERE {{ file_date_filter() }}
AND source_offer_id IS NULL

UNION ALL

-- not_null: offer_date
SELECT 'not_null_offer_date' AS test_name, id
FROM {{ ref('silver_offers') }}
WHERE {{ file_date_filter() }}
AND offer_date IS NULL

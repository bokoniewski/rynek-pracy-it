-- tests/silver_offer_contracts.sql
-- Testy dla modelu silver_offer_contracts
-- Zakres: tylko dane z bieżącego dnia (FILE_DATE)

-- not_null: id
SELECT 'not_null_id' AS test_name, id
FROM {{ ref('silver_offer_contracts') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND id IS NULL

UNION ALL

-- not_null: offer_id
SELECT 'not_null_offer_id' AS test_name, id
FROM {{ ref('silver_offer_contracts') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id IS NULL

UNION ALL

-- relationships: offer_id -> silver_offers.id
SELECT 'relationships_offer_id' AS test_name, id
FROM {{ ref('silver_offer_contracts') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id NOT IN (
    SELECT id FROM {{ ref('silver_offers') }}
)

UNION ALL

-- not_null: contract_name
SELECT 'not_null_contract_name' AS test_name, id
FROM {{ ref('silver_offer_contracts') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND contract_name IS NULL

UNION ALL

-- accepted_values: contract_name
SELECT 'accepted_values_contract_name' AS test_name, id
FROM {{ ref('silver_offer_contracts') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND contract_name IS NOT NULL
AND upper(contract_name) NOT IN (
    'B2B', 'UOP', 'UMOWA ZLECENIE',
    'UMOWA NA ZASTĘPSTWO', 'UMOWA O DZIEŁO', 'UMOWA O STAŻ', 'N/A'
)

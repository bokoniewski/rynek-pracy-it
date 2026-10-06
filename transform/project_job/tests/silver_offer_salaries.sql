-- tests/silver_offer_salaries.sql
-- Testy dla modelu silver_offer_salaries
-- Zakres: tylko dane z bieżącego dnia (FILE_DATE)

-- not_null: id
SELECT 'not_null_id' AS test_name, id
FROM {{ ref('silver_offer_salaries') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND id IS NULL

UNION ALL

-- not_null: offer_id
SELECT 'not_null_offer_id' AS test_name, id
FROM {{ ref('silver_offer_salaries') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id IS NULL

UNION ALL

-- relationships: offer_id -> silver_offers.id
SELECT 'relationships_offer_id' AS test_name, id
FROM {{ ref('silver_offer_salaries') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND offer_id NOT IN (
    SELECT id FROM {{ ref('silver_offers') }}
)

UNION ALL

-- accepted_values: contract_type
SELECT 'accepted_values_contract_type' AS test_name, id
FROM {{ ref('silver_offer_salaries') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND contract_type IS NOT NULL
AND upper(contract_type) NOT IN (
    'UMOWA NA ZASTĘPSTWO', 'UMOWA O DZIEŁO', 'UMOWA O STAŻ',
    'B2B', 'UOP', 'UMOWA ZLECENIE', 'ANY'
)

UNION ALL

-- accepted_values: currency
SELECT 'accepted_values_currency' AS test_name, id
FROM {{ ref('silver_offer_salaries') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND currency IS NOT NULL
AND upper(currency) NOT IN ('PLN')

UNION ALL

-- accepted_values: period
SELECT 'accepted_values_period' AS test_name, id
FROM {{ ref('silver_offer_salaries') }}
WHERE {{ file_date_filter_by_offer_id() }}
AND period IS NOT NULL
AND upper(period) NOT IN ('MONTHLY', 'HOURLY', 'DAILY', 'ANNUALLY')

-- =============================================================================
-- SKRYPT: Tworzenie schematów
-- PROJEKT: Project_job
-- OPIS: Inicjalizacja trzech warstw architektonicznych (Bronze / Silver / Gold)
-- KOLEJNOŚĆ WYKONANIA: 1
-- =============================================================================

-- ---------------------------------------------------------------------------
-- BRONZE – surowe dane, bez transformacji, 1:1 ze źródłem
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS bronze;

-- ---------------------------------------------------------------------------
-- SILVER – dane oczyszczone, znormalizowane, model relacyjny
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS silver;

-- ---------------------------------------------------------------------------
-- GOLD – model wymiarowy (Dim/Fact) gotowy pod BI
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS gold;

-- ---------------------------------------------------------------------------
-- maintenance – model pod zarządzanie bazą danych
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS maintenance;



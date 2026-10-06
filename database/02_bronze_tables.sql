

-- =============================================================================
-- SKRYPT: Tabela audytowa – warstwa BRONZE
-- PROJEKT: Project_job
-- OPIS: Rejestr wgranych plików JSON do warstwy bronze.
--       Każde uruchomienie loadera zapisuje jeden rekord.
--       Tabela służy jako podstawa do decyzji Airflow o procesowaniu do silver.
-- KOLEJNOŚĆ WYKONANIA: 2
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: bronze.audit_file_log
-- OPIS:   Rejestr wgranych plików JSON.
--
--         Logika statusów:
--         - SUCCESS       → records_inserted > 0, records_errors = 0
--                           plik gotowy do procesowania do silver
--         - PARTIAL       → records_inserted > 0, records_errors > 0
--                           część danych wgrana, Airflow procesuje ale wysyła WARNING
--         - SUCCESS_EMPTY → records_inserted = 0, records_errors = 0
--                           wszystkie rekordy to duplikaty, nie ma co procesować
--         - FAILED        → records_inserted = 0, records_errors > 0
--                           krytyczny błąd, Airflow pomija plik
--
--         Flaga is_processed_to_silver:
--         - FALSE (default) → plik jeszcze nie był procesowany do silver
--         - TRUE            → silver loader zakończył procesowanie tego pliku
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bronze.audit_file_log (

    -- -------------------------------------------------------------------------
    -- Klucz techniczny
    -- -------------------------------------------------------------------------
    file_id                 SERIAL          PRIMARY KEY,

    -- -------------------------------------------------------------------------
    -- Identyfikacja pliku
    -- -------------------------------------------------------------------------
    file_name               TEXT            NOT NULL,           -- np. "joinit_20260315_164131.json"
    portal                  TEXT            NOT NULL,           -- np. "justjoin.it", "pracuj.pl"
    file_date               DATE,                               -- data wyciągnięta z nazwy pliku

    -- -------------------------------------------------------------------------
    -- Timestamp wgrania
    -- -------------------------------------------------------------------------
    loaded_at               TIMESTAMP       DEFAULT NOW(),      -- kiedy loader był uruchomiony

    -- -------------------------------------------------------------------------
    -- Statystyki ładowania
    -- -------------------------------------------------------------------------
    records_total           INT,                                -- ile rekordów było w pliku JSON
    records_inserted        INT,                                -- ile faktycznie wstawiono do bazy
    records_skipped         INT,                                -- ile pominięto (duplikaty)
    records_errors          INT,                                -- ile rekordów nie udało się zmapować

    -- -------------------------------------------------------------------------
    -- Status i flaga procesowania do silver
    -- -------------------------------------------------------------------------
    status                  TEXT            NOT NULL,           -- SUCCESS / PARTIAL / SUCCESS_EMPTY / FAILED
    is_processed_to_silver  BOOLEAN         DEFAULT FALSE,      -- czy silver loader już przetworzył ten plik
    processed_to_silver_at  TIMESTAMP       DEFAULT NULL        -- kiedy silver loader zakończył procesowanie

);


-- =============================================================================
-- INDEKSY – bronze.audit_file_log
-- =============================================================================

-- Filtrowanie po dacie pliku
CREATE INDEX IF NOT EXISTS idx_bronze_audit_file_date
    ON bronze.audit_file_log (file_date);

-- Filtrowanie po portalu i dacie – monitoring i debugowanie
CREATE INDEX IF NOT EXISTS idx_bronze_audit_portal_date
    ON bronze.audit_file_log (portal, file_date);

-- Wyszukiwanie po nazwie pliku – sprawdzenie czy plik był już wgrywany
CREATE INDEX IF NOT EXISTS idx_bronze_audit_file_name
    ON bronze.audit_file_log (file_name);






-- =============================================================================
-- SKRYPT: Tabele i indeksy – warstwa BRONZE
-- PROJEKT: Project_job
-- OPIS: Surowe dane ładowane bezpośrednio ze źródeł (JSON/scraping).
--       Brak walidacji, brak transformacji – dane 1:1.
-- KOLEJNOŚĆ WYKONANIA: 3
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================



-- -----------------------------------------------------------------------------
-- TABELA: bronze.raw_offers_pracuj
-- ŹRÓD�O:  pracuj.pl
-- OPIS:    Surowe oferty pracy załadowane z plików JSON.
--          Pola skalarne jako TEXT, pola wielowartościowe jako JSONB.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bronze.raw_offers_pracuj (

    -- -------------------------------------------------------------------------
    -- Klucz techniczny
    -- -------------------------------------------------------------------------
    raw_id                  SERIAL          PRIMARY KEY,

    -- -------------------------------------------------------------------------
    -- Metadane ładowania (audit columns)
    -- -------------------------------------------------------------------------
    --source_file             TEXT,                               -- nazwa pliku JSON źródłowego
	source_file_id    		INT    			NOT NULL REFERENCES bronze.audit_file_log(file_id),
    loaded_at               TIMESTAMP       DEFAULT NOW(),      -- timestamp załadowania rekordu do bazy

    -- -------------------------------------------------------------------------
    -- Pola skalarne – typ TEXT, bez walidacji na poziomie bronze
    -- -------------------------------------------------------------------------
    offer_id                TEXT,                               -- natywne ID oferty z portalu
    url                     TEXT,                               -- bezpośredni link do oferty
    title                   TEXT,                               -- tytuł stanowiska
    employer                TEXT,                               -- nazwa pracodawcy
    employer_address        TEXT,                               -- surowy adres (miasto + województwo w jednym stringu)
    job_workplace           TEXT,                               -- lokalizacja miejsca pracy
    job_contract            TEXT,                               -- typ umowy, np. "umowa o pracę"
    job_schedule            TEXT,                               -- wymiar etatu, np. "pełny etat"
    employment_type         TEXT,                               -- poziom stanowiska, np. "senior", "mid", "junior"
    job_modes               TEXT,                               -- tryb pracy, może być kilka wartości, np. "praca zdalna, praca hybrydowa"
    specialization          TEXT,                               -- specjalizacja / kategoria zawodowa

    -- -------------------------------------------------------------------------
    -- Pola wielowartościowe – JSONB (listy z JSON)
    -- -------------------------------------------------------------------------
    salary_info             JSONB,                              -- informacje o wynagrodzeniu (może zawierać widełki, walutę, typ)
    technology_expected     JSONB,                              -- lista wymaganych technologii
    technology_optional     JSONB,                              -- lista technologii mile widzianych
    responsibilities        JSONB,                              -- lista obowiązków na stanowisku
    requirements_expected   JSONB,                              -- lista wymagań obowiązkowych
    requirements_optional   JSONB,                              -- lista wymagań opcjonalnych
    offered                 JSONB,                              -- lista benefitów opisanych przez pracodawcę (tekst swobodny)
    benefits                JSONB                               -- lista ustandaryzowanych benefitów z portalu

);


-- =============================================================================
-- INDEKSY – bronze.raw_offers_pracuj
-- =============================================================================

-- Wyszukiwanie / deduplicacja po natywnym ID oferty z portalu
CREATE INDEX IF NOT EXISTS idx_bronze_pracuj_offer_id
    ON bronze.raw_offers_pracuj (offer_id);

-- Filtrowanie po dacie załadowania, np. "pokaż oferty załadowane dziś"
CREATE INDEX IF NOT EXISTS idx_bronze_pracuj_loaded_at
    ON bronze.raw_offers_pracuj (loaded_at);
	
-- Filtrowanie po id wgranego pliku
CREATE INDEX IF NOT EXISTS idx_bronze_pracuj_source_file_id
    ON bronze.raw_offers_pracuj (source_file_id);


/* -- Dla Bronze na razie bez sensu 
-- GIN na JSONB – umożliwia zapytania containment, np.:
-- WHERE technology_expected @> '["Python"]'
CREATE INDEX IF NOT EXISTS idx_bronze_pracuj_tech_expected
    ON bronze.raw_offers_pracuj USING GIN (technology_expected);

CREATE INDEX IF NOT EXISTS idx_bronze_pracuj_tech_optional
    ON bronze.raw_offers_pracuj USING GIN (technology_optional);

CREATE INDEX IF NOT EXISTS idx_bronze_pracuj_benefits
    ON bronze.raw_offers_pracuj USING GIN (benefits);
*/
	
	
	
	
	
	



-- =============================================================================
-- SKRYPT: Tabela i indeksy – warstwa BRONZE – justjoin.it
-- PROJEKT: Project_job
-- OPIS: Surowe dane ładowane bezpośrednio ze źródła (JSON/scraping).
--       Brak walidacji, brak transformacji – dane 1:1 ze źródłem.
-- KOLEJNOŚĆ WYKONANIA: 3
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================
 
 
-- -----------------------------------------------------------------------------
-- TABELA: bronze.raw_offers_joinit
-- ŹRÓD�O:  justjoin.it
-- OPIS:    Surowe oferty pracy załadowane z plików JSON
--          Pola skalarne jako TEXT, pola wielowartościowe jako JSONB.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bronze.raw_offers_joinit (
 
    -- -------------------------------------------------------------------------
    -- Klucz techniczny
    -- -------------------------------------------------------------------------
    raw_id                  SERIAL          PRIMARY KEY,
 
    -- -------------------------------------------------------------------------
    -- Metadane ładowania (audit columns)
    -- -------------------------------------------------------------------------
    --source_file             TEXT,                               -- nazwa pliku JSON źródłowego
	source_file_id    		INT    			NOT NULL REFERENCES bronze.audit_file_log(file_id),
    loaded_at               TIMESTAMP       DEFAULT NOW(),      -- timestamp załadowania rekordu do bazy
 
    -- -------------------------------------------------------------------------
    -- Pola skalarne – typ TEXT, bez walidacji na poziomie bronze
    -- -------------------------------------------------------------------------
    portal                  TEXT,                               -- identyfikator portalu, zawsze "justjoin.it"
    offer_id                TEXT,                               -- natywne ID oferty (hash z URL w scraper)
    url                     TEXT,                               -- bezpośredni link do oferty
    title                   TEXT,                               -- tytuł stanowiska
    date_posted             TIMESTAMP,                          -- data publikacji oferty (ISO 8601 z JSON)
    valid_through           TIMESTAMP,                          -- data ważności oferty (ISO 8601 z JSON)
    employer                TEXT,                               -- nazwa pracodawcy
    employer_url            TEXT,                               -- URL strony pracodawcy
	specialization			TEXT,								-- Specjalizacja/Kategoria
 
    -- -------------------------------------------------------------------------
    -- Lokalizacja – rozbita na osobne kolumny (w źródle zagnieżdżony obiekt)
    -- -------------------------------------------------------------------------
    location_city           TEXT,                               -- miasto
    location_region         TEXT,                               -- region / województwo
    location_street         TEXT,                               -- ulica
    location_postal_code    TEXT,                               -- kod pocztowy
    location_country        TEXT,                               -- kod kraju, np. "PL"
 
    -- -------------------------------------------------------------------------
    -- Szczegóły oferty
    -- -------------------------------------------------------------------------
    remote                  BOOLEAN,                            -- czy oferta jest zdalna (true/false)
    job_schedule            TEXT,                               -- wymiar etatu, np. "Full-time"
    job_contract            TEXT,                               -- typ umowy, np. "B2B", "Permanent"
    seniority               TEXT,                               -- poziom stanowiska, np. "Senior", "Mid", "Junior"
    job_mode                TEXT,                               -- tryb pracy, np. "Remote", "Hybrid", "Office"
    employment_type         TEXT,                               -- typ zatrudnienia z JSON-LD, np. "FULL_TIME"
 
    -- -------------------------------------------------------------------------
    -- Pola wielowartościowe – JSONB
    -- -------------------------------------------------------------------------
    tech_stack              JSONB,                              -- lista obiektów {name: string, level: string}
                                                                -- np. [{"name": "Python", "level": "regular"}]
	salary              	JSONB,                              -- Wynagrodzenie w formie listy
 
    -- -------------------------------------------------------------------------
    -- Opis oferty
    -- -------------------------------------------------------------------------
    description             TEXT                                -- pełny tekst opisu oferty (HTML lub plain text)
 
);
 
 
-- =============================================================================
-- INDEKSY – bronze.raw_offers_joinit
-- =============================================================================

-- Wyszukiwanie / deduplicacja po natywnym ID oferty
CREATE INDEX IF NOT EXISTS idx_bronze_joinit_offer_id
    ON bronze.raw_offers_joinit (offer_id);
 
-- Filtrowanie po dacie załadowania, np. "pokaż oferty załadowane dziś"
CREATE INDEX IF NOT EXISTS idx_bronze_joinit_loaded_at
    ON bronze.raw_offers_joinit (loaded_at);
 
-- Filtrowanie po id wgranego pliku
CREATE INDEX IF NOT EXISTS idx_bronze_joinit_source_file_id
    ON bronze.raw_offers_joinit (source_file_id);
 
/* -- Dla Bronze na razie bez sensu 
-- GIN na JSONB tech_stack – umożliwia zapytania containment, np.:
-- WHERE tech_stack @> '[{"name": "Python"}]'
CREATE INDEX IF NOT EXISTS idx_bronze_joinit_tech_stack
    ON bronze.raw_offers_joinit USING GIN (tech_stack);
*/
	
	
	



-- =============================================================================
-- SKRYPT: Tabela i indeksy – warstwa BRONZE – nofluffjobs.com
-- PROJEKT: Project_job
-- OPIS: Surowe dane ładowane bezpośrednio ze źródła (JSON/scraping).
--       Brak walidacji, brak transformacji – dane 1:1 ze źródłem.
-- KOLEJNOŚĆ WYKONANIA: 4
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: bronze.raw_offers_nofluff
-- ŹRÓD�O:  nofluffjobs.com
-- OPIS:    Surowe oferty pracy załadowane z plików JSON.
--          Pola skalarne jako TEXT, pola wielowartościowe jako JSONB.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bronze.raw_offers_nofluff (

    -- -------------------------------------------------------------------------
    -- Klucz techniczny
    -- -------------------------------------------------------------------------
    raw_id                  SERIAL          PRIMARY KEY,

    -- -------------------------------------------------------------------------
    -- Metadane ładowania (audit columns)
    -- -------------------------------------------------------------------------
    --source_file             TEXT,                               -- nazwa pliku JSON źródłowego
	source_file_id    		INT    			NOT NULL REFERENCES bronze.audit_file_log(file_id),
    loaded_at               TIMESTAMP       DEFAULT NOW(),      -- timestamp załadowania rekordu do bazy

    -- -------------------------------------------------------------------------
    -- Pola skalarne
    -- -------------------------------------------------------------------------
    offer_id                TEXT,                               -- natywne ID oferty (hash z URL w scraperze)
    url                     TEXT,                               -- bezpośredni link do oferty
	specialization			JSONB,								-- Specjalizacja/Kategoria ['Security', 'Python']
    job_title               TEXT,                               -- tytuł stanowiska
    job_level               TEXT,                               -- poziom stanowiska, np. "Mid", "Senior", "Expert"
    job_modes               TEXT,                               -- tryb pracy, np. "Praca zdalna", "Praca hybrydowa"
	job_modes_2             TEXT,                               -- tryb pracy 2
    employer                TEXT,                               -- nazwa pracodawcy
    
    -- -------------------------------------------------------------------------
    -- Pola wielowartościowe – JSONB
    -- -------------------------------------------------------------------------
	employer_address        JSONB,                              -- lista adresów
    salary_info             JSONB,                              -- lista stringów z wynagrodzeniem
                                                                -- np. ["20 160 – 24 360 PLN + VAT (B2B) miesięcznie"]
                                                                -- może zawierać kilka wpisów (B2B + UoP w osobnych elementach)

    technology_expected     JSONB,                              -- flat lista wymaganych technologii / umiejętności
                                                                -- np. ["LLM", "GenAI", "SQL", "Angielski (B2)"]

    technology_optional     JSONB,                              -- flat lista technologii mile widzianych

    requirements_expected   JSONB,                              -- lista wymagań obowiązkowych (pełne zdania)

    requirements_optional   JSONB,                              -- lista wymagań opcjonalnych

    responsibilities        JSONB,                              -- lista obowiązków na stanowisku

    details_responsibilities JSONB,                             -- dodatkowe warunki oferty
                                                                -- np. ["Start ASAP", "Praca w pełni zdalna", "Płatny urlop dla: B2B"]

    office_benefits         JSONB,                              -- lista udogodnień biurowych

    benefits                JSONB                               -- lista benefitów pracowniczych

);


-- =============================================================================
-- INDEKSY – bronze.raw_offers_nofluff
-- =============================================================================

-- Wyszukiwanie / deduplicacja po natywnym ID oferty
CREATE INDEX IF NOT EXISTS idx_bronze_nofluff_offer_id
    ON bronze.raw_offers_nofluff (offer_id);

-- Filtrowanie po dacie załadowania, np. "pokaż oferty załadowane dziś"
CREATE INDEX IF NOT EXISTS idx_bronze_nofluff_loaded_at
    ON bronze.raw_offers_nofluff (loaded_at);
	
-- Filtrowanie po id wgranego pliku
CREATE INDEX IF NOT EXISTS idx_bronze_nofluff_source_file_id
    ON bronze.raw_offers_nofluff (source_file_id);

/* -- Dla Bronze na razie bez sensu 
-- GIN na JSONB – umożliwia zapytania containment, np.:
-- WHERE technology_expected @> '["Python"]'
CREATE INDEX IF NOT EXISTS idx_bronze_nofluff_tech_expected
    ON bronze.raw_offers_nofluff USING GIN (technology_expected);

CREATE INDEX IF NOT EXISTS idx_bronze_nofluff_tech_optional
    ON bronze.raw_offers_nofluff USING GIN (technology_optional);

CREATE INDEX IF NOT EXISTS idx_bronze_nofluff_benefits
    ON bronze.raw_offers_nofluff USING GIN (benefits);
*/







-- =============================================================================
-- SKRYPT: Tabela i indeksy – warstwa BRONZE – theprotocol.it
-- PROJEKT: Project_job
-- OPIS: Surowe dane ładowane bezpośrednio ze źródła (JSON/scraping).
--       Brak walidacji, brak transformacji – dane 1:1 ze źródłem.
-- KOLEJNOŚĆ WYKONANIA: 5
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: bronze.raw_offers_protocol
-- ŹRÓD�O:  theprotocol.it
-- OPIS:    Surowe oferty pracy załadowane z plików JSON.
--          Pola skalarne jako TEXT, pola wielowartościowe jako JSONB.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bronze.raw_offers_protocol (

    -- -------------------------------------------------------------------------
    -- Klucz techniczny
    -- -------------------------------------------------------------------------
    raw_id                  SERIAL          PRIMARY KEY,

    -- -------------------------------------------------------------------------
    -- Metadane ładowania (audit columns)
    -- -------------------------------------------------------------------------
    --source_file             TEXT,                               -- nazwa pliku JSON źródłowego
	source_file_id    		INT    			NOT NULL REFERENCES bronze.audit_file_log(file_id),
    loaded_at               TIMESTAMP       DEFAULT NOW(),      -- timestamp załadowania rekordu do bazy

    -- -------------------------------------------------------------------------
    -- Pola skalarne
    -- -------------------------------------------------------------------------
    offer_id                TEXT,                               -- natywne ID oferty (hash z URL w scraperze)
    url                     TEXT,                               -- bezpośredni link do oferty
    offer_title             TEXT,                               -- tytuł stanowiska
    offer_company           TEXT,                               -- nazwa pracodawcy
    offer_level             TEXT,                               -- poziom stanowiska, np. "senior", "mid • senior"
                                                                -- może zawierać kilka wartości rozdzielonych "•"
    offer_modes             TEXT,                               -- tryb pracy, np. "hybrid", "zdalna • hybrydowa"
                                                                -- może zawierać kilka wartości rozdzielonych "•"
    offer_location          TEXT,                               -- surowa lokalizacja, np. "Kraków, Lesser Poland"

    -- -------------------------------------------------------------------------
    -- Pola wielowartościowe – JSONB
    -- -------------------------------------------------------------------------
    salary_info             JSONB,                              -- lista obiektów {contract_type, salary}
                                                                -- np. [{"contract_type": "B2B contract (full-time)", "salary": "21 000 - 25 000 zł net (+ VAT) / mth."}]
                                                                -- może zawierać kilka wpisów (B2B + UoP w osobnych obiektach)

    tech_required           JSONB,                              -- flat lista wymaganych technologii
                                                                -- np. ["OpenShift", "GitOps"]

    tech_optional           JSONB,                              -- flat lista technologii mile widzianych

    offer_responsibilities  JSONB,                              -- lista obowiązków na stanowisku

    offer_requirements      JSONB,                              -- lista wymagań obowiązkowych

    offer_nice_to_have      JSONB,                              -- lista wymagań opcjonalnych / mile widzianych
                                                                -- osobne pole (w nofluff wmieszane w requirements_optional)

    offer_offered           JSONB,                              -- lista benefitów opisanych przez pracodawcę (tekst swobodny)

    offer_benefits          JSONB                               -- lista ustandaryzowanych benefitów z portalu

);


-- =============================================================================
-- INDEKSY – bronze.raw_offers_protocol
-- =============================================================================

-- Wyszukiwanie / deduplicacja po natywnym ID oferty
CREATE INDEX IF NOT EXISTS idx_bronze_protocol_offer_id
    ON bronze.raw_offers_protocol (offer_id);

-- Filtrowanie po dacie załadowania, np. "pokaż oferty załadowane dziś"
CREATE INDEX IF NOT EXISTS idx_bronze_protocol_loaded_at
    ON bronze.raw_offers_protocol (loaded_at);
	
-- Filtrowanie po id wgranego pliku
CREATE INDEX IF NOT EXISTS idx_bronze_protocol_source_file_id
    ON bronze.raw_offers_protocol (source_file_id);
















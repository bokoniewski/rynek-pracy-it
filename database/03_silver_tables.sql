-- =============================================================================
-- SKRYPT: Tabele i indeksy – warstwa SILVER
-- PROJEKT: Project_job
-- OPIS: Dane oczyszczone strukturalnie, połączone z wszystkich portali.
-- KOLEJNOŚĆ WYKONANIA: 7
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: silver.def_portal
-- OPIS:   Słownik portali – zasilany ręcznie
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.def_portal (

    id              SERIAL          PRIMARY KEY,
    portal_name     TEXT            NOT NULL,                   -- np. "pracuj", "justjoin"
    portal_url      TEXT,                                       -- np. "https://pracuj.pl"
    is_active       BOOLEAN         DEFAULT TRUE,               -- czy portal jest aktywnie scrapowany
    created_at      TIMESTAMP       DEFAULT NOW()

);

-- Unikalność nazwy portalu
CREATE UNIQUE INDEX IF NOT EXISTS idx_silver_def_portal_name
    ON silver.def_portal (portal_name);


-- -----------------------------------------------------------------------------
-- TABELA: silver.def_requirement_type
-- OPIS:   Słownik typów wymagalności – zasilany ręcznie
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.def_requirement_type (

    id                      SERIAL  PRIMARY KEY,
    requirement_type_name   TEXT    NOT NULL,                   -- "wymagane" / "opcjonalne"
    created_at              TIMESTAMP DEFAULT NOW()

);

-- Unikalność nazwy typu
CREATE UNIQUE INDEX IF NOT EXISTS idx_silver_def_req_type_name
    ON silver.def_requirement_type (requirement_type_name);



-- -----------------------------------------------------------------------------
-- TABELA: silver.offers
-- OPIS:   Główna tabela ofert – pola 1:1, klucze obce do pozostałych tabel
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offers (

    -- -------------------------------------------------------------------------
    -- Klucz techniczny
    -- -------------------------------------------------------------------------
    id                  SERIAL          PRIMARY KEY,

    -- -------------------------------------------------------------------------
    -- Klucze obce
    -- -------------------------------------------------------------------------
    portal_id           INT             NOT NULL REFERENCES silver.def_portal(id),
    bronze_file_id      INT             NOT NULL REFERENCES bronze.audit_file_log(file_id),

    -- -------------------------------------------------------------------------
    -- Identyfikacja oferty
    -- -------------------------------------------------------------------------
    source_offer_id     TEXT,                                   -- oryginalne ID z portalu
    url                 TEXT,                                   -- bezpośredni link do oferty

    -- -------------------------------------------------------------------------
    -- Dane oferty
    -- ------------------------------------------------------------------------- 
    title               TEXT,                                   -- tytuł stanowiska
	company_name        TEXT,									-- nazwa firmy
    offer_date          DATE,                                   -- file_date

    -- -------------------------------------------------------------------------
    -- Audit
    -- -------------------------------------------------------------------------
    created_at          TIMESTAMP       DEFAULT NOW()

);




CREATE INDEX IF NOT EXISTS idx_silver_offers_file_date
    ON silver.offers (offer_date, bronze_file_id);




-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_levels
-- OPIS:   Poziomy stanowiska per oferta (many-to-many)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_levels (

    id          SERIAL  PRIMARY KEY,
    offer_id    INT     NOT NULL REFERENCES silver.offers(id) ON DELETE CASCADE,
    level_name  TEXT    NOT NULL                                -- "Junior" / "Mid" / "Senior" / "Expert" / "Manager" / "Director"

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_levels_offer_id
    ON silver.offer_levels (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_modes
-- OPIS:   Tryby pracy per oferta (many-to-many)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_modes (

    id          SERIAL  PRIMARY KEY,
    offer_id    INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    mode_name   TEXT    NOT NULL                                -- "Remote" / "Hybrid" / "Office"

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_modes_offer_id
    ON silver.offer_modes (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_contracts
-- OPIS:   Typy umów per oferta (many-to-many)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_contracts (

    id              SERIAL  PRIMARY KEY,
    offer_id        INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    contract_name   TEXT    NOT NULL                            -- "B2B" / "UoP" / "Zlecenie" / "Kontrakt"

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_contracts_offer_id
    ON silver.offer_contracts (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_schedules
-- OPIS:   Wymiary etatu per oferta (many-to-many)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_schedules (

    id              SERIAL  PRIMARY KEY,
    offer_id        INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    schedule_name   TEXT    NOT NULL                            -- "Full-time" / "Part-time" / "Freelance"

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_schedules_offer_id
    ON silver.offer_schedules (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_specs
-- OPIS:   Specjalizacje per oferta (many-to-many)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_specs (

    id                      SERIAL  PRIMARY KEY,
    offer_id                INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    specialization_name     TEXT    NOT NULL                    -- "Data Engineering" / "Backend" / "DevOps" itd.

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_specs_offer_id
    ON silver.offer_specs (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_salaries
-- OPIS:   Wynagrodzenia per oferta – może być kilka rekordów (B2B + UoP)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_salaries (

    id              SERIAL      PRIMARY KEY,
    offer_id        INT         NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    contract_type   TEXT,                                       -- "B2B" / "UoP" / NULL
    salary_min      NUMERIC,                                    -- minimalne wynagrodzenie
    salary_max      NUMERIC,                                    -- maksymalne wynagrodzenie
    currency        TEXT,                                       -- "PLN" / "EUR"
    period          TEXT,                                       -- "monthly" / "hourly"
    salary_type     TEXT                                        -- "Netto" / "Brutto"

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_salaries_offer_id
    ON silver.offer_salaries (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_locations
-- OPIS:   Lokalizacje per oferta – może być kilka rekordów
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_locations (

    id              SERIAL  PRIMARY KEY,
    offer_id        INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    city            TEXT,                                       -- miasto
    region          TEXT,                                       -- województwo / region
    country         TEXT    DEFAULT 'PL'                        -- kod kraju

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_locations_offer_id
    ON silver.offer_locations (offer_id);



-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_technologies
-- OPIS:   Technologie per oferta rozbite z JSONB
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_technologies (

    id                      SERIAL  PRIMARY KEY,
    offer_id                INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    technology_name         TEXT    NOT NULL,                   -- "Python" / "SQL" / "Docker"
    requirement_type_id     INT     NOT NULL REFERENCES silver.def_requirement_type(id)

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_technologies_offer_id
    ON silver.offer_technologies (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_benefits
-- OPIS:   Benefity per oferta rozbite z JSONB
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_benefits (

    id              SERIAL  PRIMARY KEY,
    offer_id        INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    benefit_name    TEXT    NOT NULL

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_benefits_offer_id
    ON silver.offer_benefits (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_requirements
-- OPIS:   Wymagania per oferta z podziałem na wymagane / opcjonalne
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_requirements (

    id                      SERIAL  PRIMARY KEY,
    offer_id                INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    requirement_text        TEXT    NOT NULL,
    requirement_type_id     INT     NOT NULL REFERENCES silver.def_requirement_type(id)

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_requirements_offer_id
    ON silver.offer_requirements (offer_id);


-- -----------------------------------------------------------------------------
-- TABELA: silver.offer_responsibilities
-- OPIS:   Obowiązki per oferta
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.offer_responsibilities (

    id                      SERIAL  PRIMARY KEY,
    offer_id                INT     NOT NULL REFERENCES silver.offers(id)  ON DELETE CASCADE,
    responsibility_text     TEXT    NOT NULL,
    requirement_type_id     INT     NOT NULL REFERENCES silver.def_requirement_type(id)

);

CREATE INDEX IF NOT EXISTS idx_silver_offer_resp_offer_id
    ON silver.offer_responsibilities (offer_id);


-- =============================================================================
-- DANE INICJALNE – słowniki
-- Uruchom po utworzeniu tabel
-- =============================================================================

-- silver.def_portal
INSERT INTO silver.def_portal (portal_name, portal_url, is_active) VALUES
    ('pracuj',       'https://pracuj.pl',            TRUE),
    ('joinit',     'https://justjoin.it',          TRUE),
    ('nofluff', 'https://nofluffjobs.com',      TRUE),
    ('protocol',  'https://theprotocol.it',       TRUE)
ON CONFLICT (portal_name) DO NOTHING;

-- silver.def_requirement_type
INSERT INTO silver.def_requirement_type (requirement_type_name) VALUES
    ('wymagane'),
    ('opcjonalne')
ON CONFLICT (requirement_type_name) DO NOTHING;
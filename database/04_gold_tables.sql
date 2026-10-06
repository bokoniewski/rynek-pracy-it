-- =============================================================================
-- SKRYPT: Tabele – warstwa GOLD
-- PROJEKT: Project_job
-- OPIS: Warstwa analityczna – wymiary (D_) i fakty (F_) gotowe pod BI (Metabase).
--       Tabele faktów dziennych partycjonowane po d_date_id per miesiąc.
--       Tabele AGG bez partycjonowania – małe wolumeny.
-- KOLEJNOŚĆ WYKONANIA: 4
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================


-- =============================================================================
-- WYMIARY
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: gold.D_DATE
-- OPIS:   Wymiar czasu – wypełniany skryptem generującym daty (2026-2027)
--         d_date_id jako INT w formacie YYYYMMDD, np. 20260315
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_DATE (

    d_date_id       INT             PRIMARY KEY,                -- np. 20260315
    date_actual     DATE            NOT NULL,
    day             INT,                                        -- 1-31
    month           INT,                                        -- 1-12
    month_name      TEXT,                                       -- "Styczeń" / "Luty"
    quarter         INT,                                        -- 1-4
    year            INT,                                        -- np. 2026
    week            INT,                                        -- numer tygodnia ISO
    day_of_week     INT,                                        -- 1-7
    is_weekend      BOOLEAN

);


-- -----------------------------------------------------------------------------
-- TABELA: gold.D_LEVEL
-- OPIS:   Wymiar poziomu doświadczenia – zasilany ręcznie
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_LEVEL (

    d_level_id      SERIAL          PRIMARY KEY,
    level_name      TEXT            NOT NULL,                   -- "Junior" / "Mid" / "Senior" / "Expert"
    created_at      TIMESTAMP       DEFAULT NOW()

);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gold_d_level_name
    ON gold.D_LEVEL (level_name);



-- -----------------------------------------------------------------------------
-- TABELA: gold.D_LOCATION
-- OPIS:   Wymiar lokalizacji – wypełniany skryptem z miastami Polski
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_LOCATION (

    d_location_id   SERIAL          PRIMARY KEY,
    city            TEXT,
    region          TEXT,
    country         TEXT            DEFAULT 'PL',
	like_patterns	JSONB,										-- ["Warsaw", "Warszawa"] miasta w różnych jezykach sposób na anglojezyczne miejscowości aby nie robić case na każdy przypadek
	created_at      TIMESTAMP       DEFAULT NOW()

);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gold_d_location_city
    ON gold.D_LOCATION (city);


-- -----------------------------------------------------------------------------
-- TABELA: gold.D_TECHNOLOGY
-- OPIS:   Wymiar technologii – zasilany przez dbt
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_TECHNOLOGY (
    d_tech_id       SERIAL  PRIMARY KEY,
    tech_name       TEXT    NOT NULL UNIQUE,  -- "Angielski", "Docker", "Kubernetes"
    like_patterns   JSONB,                    -- ["%angielski%", "%english%"]
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gold_d_technology_name
    ON gold.D_TECHNOLOGY (tech_name);


-- -----------------------------------------------------------------------------
-- TABELA: gold.D_BENEFIT
-- OPIS:   Wymiar benefitów – zasilany przez dbt
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_BENEFIT (

    d_benefit_id    SERIAL          PRIMARY KEY,
    benefit_name    TEXT            NOT NULL,
	like_patterns   JSONB,							
    created_at      TIMESTAMP       DEFAULT NOW()

);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gold_d_benefit_name
    ON gold.D_BENEFIT (benefit_name);


-- -----------------------------------------------------------------------------
-- TABELA: gold.D_SPECS
-- OPIS:   Wymiar specjalizacji – zasilany przez dbt
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_SPECS (

    d_spec_id       SERIAL          PRIMARY KEY,
    spec_name       TEXT            NOT NULL,
    spec_aliases    JSONB,
    priority        INT             NOT NULL,       -- 1 = najwyższy priorytet przy remisie
    created_at      TIMESTAMP       DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gold_d_specs_name
    ON gold.D_SPECS (spec_name);

CREATE INDEX IF NOT EXISTS idx_d_specs_aliases ON gold.D_SPECS USING GIN (spec_aliases);




-- -----------------------------------------------------------------------------
-- TABELA: gold.D_MODE
-- OPIS:   Wymiar trybu pracy – zasilany ręcznie
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_MODE (

    d_mode_id       SERIAL          PRIMARY KEY,
    mode_name       TEXT            NOT NULL,                   -- "Remote" / "Hybrid" / "Office"
    created_at      TIMESTAMP       DEFAULT NOW()

);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gold_d_mode_name
    ON gold.D_MODE (mode_name);


-- -----------------------------------------------------------------------------
-- TABELA: gold.D_CONTRACT
-- OPIS:   Wymiar typu umowy – zasilany ręcznie
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_CONTRACT (

    d_contract_id   SERIAL          PRIMARY KEY,
    contract_name   TEXT            NOT NULL,                   -- "B2B" / "UoP" / "Zlecenie / Zastępstwo"
    created_at      TIMESTAMP       DEFAULT NOW()

);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gold_d_contract_name
    ON gold.D_CONTRACT (contract_name);


-- -----------------------------------------------------------------------------
-- TABELA: gold.D_REQUIREMENT_TYPE
-- OPIS:   Wymiar typu wymagalności – zasilany ręcznie
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.D_REQUIREMENT_TYPE (

    d_req_type_id           SERIAL  PRIMARY KEY,
    requirement_type_name   TEXT,                                -- "wymagane" / "opcjonalne"
	created_at      TIMESTAMP       DEFAULT NOW()

);

CREATE UNIQUE INDEX IF NOT EXISTS idx_gold_d_req_type_name
    ON gold.D_REQUIREMENT_TYPE (requirement_type_name);





-- =============================================================================
-- FAKTY – TECHNOLOGIE I BENEFITY
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_DAY_OFFERS_TECHNOLOGY
-- OPIS:   Zestawienie technologii per dzień – ranking wymaganych i opcjonalnych
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_DAY_OFFERS_TECHNOLOGY (

    d_date_id       INT             NOT NULL REFERENCES gold.D_DATE(d_date_id),
    d_technology_id INT             NOT NULL REFERENCES gold.D_TECHNOLOGY(d_tech_id),
    d_req_type_id   INT             NOT NULL REFERENCES gold.D_REQUIREMENT_TYPE(d_req_type_id),
    d_spec_id       INT             NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    total_offers    INT             NOT NULL

);


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_DAY_OFFERS_BENEFIT
-- OPIS:   Ranking benefitów per dzień
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_DAY_OFFERS_BENEFIT (

    d_date_id       INT             NOT NULL REFERENCES gold.D_DATE(d_date_id),
    d_benefit_id    INT             NOT NULL REFERENCES gold.D_BENEFIT(d_benefit_id),
    total_offers    INT             NOT NULL

);


-- =============================================================================
-- FAKTY – OFERTY DZIENNE (PARTYCJONOWANE)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_DAY_OFFERS
-- OPIS:   Fakty ofert per dzień – tryb pracy (Remote/Hybrid/Office)
--         Partycjonowana po d_date_id per miesiąc
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_DAY_OFFERS (

    d_date_id       INT             NOT NULL,
    d_spec_id       INT             NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id      INT             NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id       INT             NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id   INT             NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    total_offers    INT             NOT NULL

) PARTITION BY RANGE (d_date_id);




-- -----------------------------------------------------------------------------
-- TABELA: gold.F_DAY_OFFERS_LOC
-- OPIS:   Fakty ofert per dzień z lokalizacją – tylko Hybrid/Office
--         Partycjonowana po d_date_id per miesiąc
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_DAY_OFFERS_LOC (

    d_date_id       INT             NOT NULL,
    d_location_id   INT             NOT NULL REFERENCES gold.D_LOCATION(d_location_id),
    d_spec_id       INT             NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id      INT             NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id       INT             NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id   INT             NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    total_offers    INT             NOT NULL

) PARTITION BY RANGE (d_date_id);




-- =============================================================================
-- FAKTY – OFERTY AGG (MIESIĘCZNE I ROCZNE)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_MONTH_OFFERS_AGG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_MONTH_OFFERS_AGG (

    year            INT             NOT NULL,
	month           INT             NOT NULL,
    d_spec_id       INT             NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id      INT             NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id       INT             NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id   INT             NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    total_offers    INT             NOT NULL

);


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_MONTH_OFFERS_LOC_AGG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_MONTH_OFFERS_LOC_AGG (

    year            INT             NOT NULL,
	month           INT             NOT NULL,
    d_location_id   INT             NOT NULL REFERENCES gold.D_LOCATION(d_location_id),
    d_spec_id       INT             NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id      INT             NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id       INT             NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id   INT             NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    total_offers    INT             NOT NULL

);


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_YEAR_OFFERS_AGG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_YEAR_OFFERS_AGG (

    year            INT             NOT NULL,
    d_spec_id       INT             NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id      INT             NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id       INT             NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id   INT             NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    total_offers    INT             NOT NULL

);


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_YEAR_OFFERS_LOC_AGG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_YEAR_OFFERS_LOC_AGG (

    year            INT             NOT NULL,
    d_location_id   INT             NOT NULL REFERENCES gold.D_LOCATION(d_location_id),
    d_spec_id       INT             NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id      INT             NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id       INT             NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id   INT             NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    total_offers    INT             NOT NULL

);


-- =============================================================================
-- FAKTY – WYNAGRODZENIA
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_DAY_SALARIES
-- OPIS:   Mediany wynagrodzeń per dzień per kombinacja wymiarów
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_DAY_SALARIES (

    d_date_id           INT         NOT NULL REFERENCES gold.D_DATE(d_date_id),
    d_spec_id           INT         NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id          INT         NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id           INT         NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id       INT         NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    salary_min_median   NUMERIC,
    salary_max_median   NUMERIC,
    offer_count         INT                                         -- ile ofert weszło do mediany

);


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_MONTH_SALARIES_AGG
-- OPIS:   Mediany wynagrodzeń per miesiąc – PERCENTILE_CONT z F_DAY_SALARIES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_MONTH_SALARIES_AGG (

    year                INT         NOT NULL,
    month               INT         NOT NULL,
    d_spec_id           INT         NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id          INT         NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id           INT         NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id       INT         NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    salary_min_median   NUMERIC,
    salary_max_median   NUMERIC,
    offer_count         INT

);


-- -----------------------------------------------------------------------------
-- TABELA: gold.F_YEAR_SALARIES_AGG
-- OPIS:   Mediany wynagrodzeń per rok – PERCENTILE_CONT z F_MONTH_SALARIES_AGG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.F_YEAR_SALARIES_AGG (

    year                INT         NOT NULL,
    d_spec_id           INT         NOT NULL REFERENCES gold.D_SPECS(d_spec_id),
    d_level_id          INT         NOT NULL REFERENCES gold.D_LEVEL(d_level_id),
    d_mode_id           INT         NOT NULL REFERENCES gold.D_MODE(d_mode_id),
    d_contract_id       INT         NOT NULL REFERENCES gold.D_CONTRACT(d_contract_id),
    salary_min_median   NUMERIC,
    salary_max_median   NUMERIC,
    offer_count         INT

);
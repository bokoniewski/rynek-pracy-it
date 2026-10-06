-- =============================================================================
-- SKRYPT: Tabele – warstwa maintenance
-- PROJEKT: Project_job
-- OPIS: Warstwa utrzymania - tabele pomocnicze
-- KOLEJNOŚĆ WYKONANIA: 9
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================




-- -----------------------------------------------------------------------------
-- TABELA: maintenance.queue
-- OPIS:   Tabela z kolejką do wykonania (rebild index, vacum itp.)
-- -----------------------------------------------------------------------------
CREATE TABLE maintenance.queue (
    id              SERIAL          PRIMARY KEY,
    operation       TEXT            NOT NULL,   -- 'VACUUM FULL' / 'REINDEX INDEX'
    schema_name     TEXT            NOT NULL,
    object_name     TEXT            NOT NULL,   -- nazwa tabeli lub indeksu
    created_at      TIMESTAMP       DEFAULT NOW(),
    sql_command text COLLATE pg_catalog."default"
);




-- -----------------------------------------------------------------------------
-- TABELA: maintenance.pipeline_run
-- OPIS:   Tabela audytowa dla pipeline'u Airflow
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS maintenance.pipeline_run (
    id              SERIAL PRIMARY KEY,
    run_date        DATE NOT NULL,                          -- data uruchomienia (z set_run_date)
    dag_run_id      TEXT NOT NULL,                          -- ID runu z Airflow (manual__... lub scheduled__...)
    start_time      TIMESTAMP NOT NULL DEFAULT NOW(),       -- czas startu pipeline'u
    end_time        TIMESTAMP,                              -- czas zakończenia (uzupełniany na końcu)
    status          TEXT NOT NULL DEFAULT 'PENDING',        -- PENDING / SUCCESS / PARTIAL_SUCCESS / ERROR
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_run_date
    ON maintenance.pipeline_run(run_date);



-- -----------------------------------------------------------------------------
-- TABELA: maintenance.pipeline_run_step
-- OPIS:   Tabela audytowa dla pipeline'u Airflow (szczegóły wykonane kroki)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS maintenance.pipeline_run_step (
    id                  SERIAL PRIMARY KEY,
    pipeline_run_id     INT NOT NULL REFERENCES maintenance.pipeline_run(id),
    step_name           TEXT NOT NULL,                      -- task_id z Airflow
    start_time          TIMESTAMP NOT NULL DEFAULT NOW(),   -- czas startu tasku
    end_time            TIMESTAMP,                          -- czas zakończenia tasku
    status              TEXT NOT NULL DEFAULT 'PENDING',    -- PENDING / SUCCESS / ERROR / SKIPPED
    error_details       TEXT,                               -- pełny stack trace / opis błędu
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_run_step_run_id
    ON maintenance.pipeline_run_step(pipeline_run_id);

CREATE INDEX IF NOT EXISTS idx_pipeline_run_step_status
    ON maintenance.pipeline_run_step(status);



-- -----------------------------------------------------------------------------
-- TABELA: 	maintenance.notification_queue
-- OPIS: 	Tabela tymczasowa dla powiadomień pipeline'u
-- 		 	Na start każdego runu wykonywany jest TRUNCATE
-- 			Przechowuje tylko wpisy ostatniego raportu
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS maintenance.notification_queue (
    pipeline_run_id     INT,
    type                TEXT NOT NULL,          -- MAIN_INFO / WARNING / ADD_INFO
    category            TEXT NOT NULL,          -- PIPELINE / PORTAL / STORAGE / DATA_QUALITY
    title               TEXT NOT NULL,          -- krótki tytuł
    message             TEXT,                   -- szczegółowy opis
    attach              BOOLEAN DEFAULT FALSE,  -- czy rekord ma być zakładką w excelu
    view_name           TEXT,                   -- nazwa widoku SQL (dla attach=true)
    view_schema         TEXT,                   -- schema widoku (bronze/silver/gold)
    is_sent             BOOLEAN DEFAULT FALSE,  -- czy rekord został wysłany
    sent_at             TIMESTAMP,              -- kiedy został wysłany
    created_at          TIMESTAMP DEFAULT NOW()
);

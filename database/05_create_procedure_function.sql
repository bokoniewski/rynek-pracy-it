-- =============================================================================
-- SKRYPT: Procedury i funkcje do tabel
-- PROJEKT: Project_job
-- OPIS: Procedury i funkcje
-- KOLEJNOŚĆ WYKONANIA: 6
-- ZALEŻNOŚCI: 01_schemas.sql, 03_silver_tables.sql, 04_gold_tables.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Procedura: gold.CREATE_PARTITIONS_FOR_TABLE
-- OPIS:   Procedura do tworzenia partycji na cały rok
--		   Na wej. procedury podajemy schemat, nazwę tabelę   CALL gold.create_partitions_for_table('gold', 'f_day_offers');
-- -----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE maintenance.p_create_partitions_table_for_date(
    p_schema_name TEXT,
    p_table_name  TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_year  INT := EXTRACT(YEAR FROM CURRENT_DATE);
    v_year          INT;
    v_month         INT;
    v_partition_name TEXT;
    v_from_val      INT;
    v_to_val        INT;
    v_from_year     INT;
    v_from_month    INT;
    v_to_year       INT;
    v_to_month      INT;
BEGIN
    -- Iteracja: obecny rok i następny
    FOR v_year IN v_current_year .. v_current_year + 1 LOOP

        RAISE NOTICE '-- Partycje %', v_year;

        FOR v_month IN 1 .. 12 LOOP

            v_from_year  := v_year;
            v_from_month := v_month;

            -- Koniec partycji = następny miesiąc
            IF v_month = 12 THEN
                v_to_year  := v_year + 1;
                v_to_month := 1;
            ELSE
                v_to_year  := v_year;
                v_to_month := v_month + 1;
            END IF;

            v_partition_name := format('%s.%s_%s%s',
                p_schema_name,
                p_table_name,
                v_from_year,
                LPAD(v_from_month::TEXT, 2, '0')
            );

            v_from_val := v_from_year * 10000 + v_from_month * 100 + 1;
            v_to_val   := v_to_year   * 10000 + v_to_month   * 100 + 1;

            EXECUTE format(
                'CREATE TABLE IF NOT EXISTS %s
                 PARTITION OF %I.%I
                 FOR VALUES FROM (%s) TO (%s)',
                v_partition_name,
                p_schema_name,
                p_table_name,
                v_from_val,
                v_to_val
            );

            RAISE NOTICE 'Utworzono (lub istniała): % [% - %]',
                v_partition_name, v_from_val, v_to_val;

        END LOOP;
    END LOOP;

    RAISE NOTICE 'Gotowe – partycje dla %.% utworzone.', p_schema_name, p_table_name;
END;
$$;





-- -----------------------------------------------------------------------------
-- Procedura: gold.load_d_date
-- OPIS:   Procedura do tworzenia rekordów w tabeli dim dla dat na cały obecny rok i przyszły
--		   Na wej. procedury podajemy schemat, nazwę tabelę   CALL gold.load_d_date();   
-- 		   Jeśli chcesz załadować więcej lat do przodu (np. 2)   CALL gold.load_d_date(2);
-- -----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE gold.load_d_date(
    p_years_ahead INT DEFAULT 1
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_year  INT := EXTRACT(YEAR FROM CURRENT_DATE);
    v_year          INT;
    v_date          DATE;
    v_count         INT;
BEGIN
    -- Iteracja: obecny rok + lata do przodu
    FOR v_year IN v_current_year .. v_current_year + p_years_ahead LOOP

        -- Sprawdź czy rok już istnieje w tabeli
        SELECT COUNT(*) INTO v_count
        FROM gold.d_date
        WHERE year = v_year;

        IF v_count > 0 THEN
            RAISE NOTICE 'Rok % już istnieje (% rekordów) – pomijam.', v_year, v_count;
            CONTINUE;
        END IF;

        RAISE NOTICE '�aduję rok %...', v_year;

        -- Iteracja po każdym dniu roku
        v_date := make_date(v_year, 1, 1);

        WHILE EXTRACT(YEAR FROM v_date) = v_year LOOP

            INSERT INTO gold.d_date (
                d_date_id,
                date_actual,
                day,
                month,
                month_name,
                quarter,
                year,
                week,
                day_of_week,
                is_weekend
            ) VALUES (
                -- YYYYMMDD jako INT
                EXTRACT(YEAR FROM v_date)::INT * 10000
                    + EXTRACT(MONTH FROM v_date)::INT * 100
                    + EXTRACT(DAY FROM v_date)::INT,

                v_date,

                EXTRACT(DAY   FROM v_date)::INT,
                EXTRACT(MONTH FROM v_date)::INT,

                -- Nazwa miesiąca po polsku
                CASE EXTRACT(MONTH FROM v_date)::INT
                    WHEN 1  THEN 'Styczeń'
                    WHEN 2  THEN 'Luty'
                    WHEN 3  THEN 'Marzec'
                    WHEN 4  THEN 'Kwiecień'
                    WHEN 5  THEN 'Maj'
                    WHEN 6  THEN 'Czerwiec'
                    WHEN 7  THEN 'Lipiec'
                    WHEN 8  THEN 'Sierpień'
                    WHEN 9  THEN 'Wrzesień'
                    WHEN 10 THEN 'Październik'
                    WHEN 11 THEN 'Listopad'
                    WHEN 12 THEN 'Grudzień'
                END,

                -- Kwartał
                EXTRACT(QUARTER FROM v_date)::INT,

                EXTRACT(YEAR FROM v_date)::INT,

                -- Numer tygodnia ISO
                EXTRACT(WEEK FROM v_date)::INT,

                -- Dzień tygodnia: 1=Poniedziałek ... 7=Niedziela (ISO)
                EXTRACT(ISODOW FROM v_date)::INT,

                -- Weekend: Sobota(6) lub Niedziela(7)
                EXTRACT(ISODOW FROM v_date)::INT >= 6
            );

            v_date := v_date + INTERVAL '1 day';

        END LOOP;

        RAISE NOTICE 'Rok % załadowany – % rekordów.',
            v_year,
            (SELECT COUNT(*) FROM gold.d_date WHERE year = v_year);

    END LOOP;

    RAISE NOTICE 'Procedura zakończona.';
END;
$$;







-- =============================================================================
-- SKRYPT: Inne obiekty
-- PROJEKT: Project_job
-- OPIS: Tworzenie reszty obiektów w bazie (partycje, triggery, jobs, ...)
-- KOLEJNOŚĆ WYKONANIA: 99 (na samym końcu)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- OPIS:  Instalacja rozszerzenia PostgreSQL umożliwiającego analizę fragmentacji tabel i indeksów
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgstattuple;




-- -----------------------------------------------------------------------------
-- Tabela: gold.f_day_offers 
-- OPIS:   Tworzenie partycji dla tabeli gold.f_day_offers per miesiąc
-- -----------------------------------------------------------------------------
CALL maintenance.p_create_partitions_table_for_date('gold', 'f_day_offers');



-- -----------------------------------------------------------------------------
-- Tabela: gold.f_day_offers_loc 
-- OPIS:   Tworzenie partycji dla tabeli gold.f_day_offers_loc per miesiąc
-- -----------------------------------------------------------------------------
CALL maintenance.p_create_partitions_table_for_date('gold', 'f_day_offers_loc');




-- -----------------------------------------------------------------------------
-- Procedura: maintenance.p_build_queue
-- OPIS:   Procedura do tworzenia kolejki w tabeli maintenance.queue
-- 		   W poźniejszym etapie kolejka jest wywoływana przez airflow.
--		   Proces ten automatycznie utrzymuje tabele i indeksy w odpowiedniej kondycji.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE maintenance.p_build_queue(
	IN p_min_free_percent double precision DEFAULT 30.0,
	IN p_min_dead_percent double precision DEFAULT 10.0,
	IN p_min_fragmentation double precision DEFAULT 30.0,
	IN p_min_density double precision DEFAULT 70.0)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_table RECORD;
    v_index RECORD;
    v_stats RECORD;
BEGIN
    -- Wyczyść kolejkę
    TRUNCATE maintenance.queue;

    -- Sprawdź tabele pod VACUUM FULL
    FOR v_table IN
        SELECT n.nspname AS schema_name, c.relname AS table_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname IN ('bronze', 'silver', 'gold')
          AND c.relkind = 'r'
          AND c.oid NOT IN (SELECT inhrelid FROM pg_inherits)
    LOOP
        EXECUTE format(
            'SELECT free_percent, dead_tuple_percent, tuple_count FROM pgstattuple(%L)',
            v_table.schema_name || '.' || v_table.table_name
        ) INTO v_stats;

		IF v_stats.tuple_count < 1000 THEN -- tabele które mają wiecej niż 1k rekordów
		    CONTINUE;
		END IF;

        IF v_stats.free_percent > p_min_free_percent
        OR v_stats.dead_tuple_percent > p_min_dead_percent
        THEN
            INSERT INTO maintenance.queue (operation, schema_name, object_name, sql_command)
			VALUES ('VACUUM FULL', v_table.schema_name, v_table.table_name,
			        format('VACUUM FULL %I.%I', v_table.schema_name, v_table.table_name));
        END IF;
    END LOOP;

    -- Sprawdź indeksy pod REINDEX
    FOR v_index IN
        SELECT n.nspname AS schema_name, i.relname AS index_name
        FROM pg_index ix
        JOIN pg_class i  ON i.oid  = ix.indexrelid
        JOIN pg_class t  ON t.oid  = ix.indrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname IN ('bronze', 'silver', 'gold')
          AND i.relkind = 'i'
		  AND (SELECT amname FROM pg_am WHERE oid = i.relam) = 'btree'
		  AND pg_relation_size(t.oid) > 1024 * 1024 -- indeks > 1MB
		  AND pg_relation_size(i.oid) > 1024 * 1024 -- indeks > 1MB
    LOOP
        EXECUTE format(
            'SELECT avg_leaf_density, leaf_fragmentation FROM pgstatindex(%L)',
            v_index.schema_name || '.' || v_index.index_name
        ) INTO v_stats;

        IF v_stats.leaf_fragmentation > p_min_fragmentation
        OR v_stats.avg_leaf_density   < p_min_density
        THEN
            INSERT INTO maintenance.queue (operation, schema_name, object_name, sql_command)
			VALUES ('REINDEX INDEX', v_index.schema_name, v_index.index_name,
			        format('REINDEX INDEX CONCURRENTLY %I.%I', v_index.schema_name, v_index.index_name));
        END IF;
    END LOOP;

    RAISE NOTICE 'Queue built: % operations pending', (SELECT COUNT(*) FROM maintenance.queue);
END;
$BODY$;


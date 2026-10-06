-- =============================================================================
-- SKRYPT: Widoki pomocnicze – warstwa maintenance
-- PROJEKT: Project_job
-- OPIS: Gotowy create view dla warstwy maintenance
-- KOLEJNOŚĆ WYKONANIA: 10
-- ZALEŻNOŚCI: 01_schemas.sql
-- =============================================================================



-- -----------------------------------------------------------------------------
-- Widok: bronze.v_bronze_obj_sizes 
-- OPIS:  Widok do analizy bieżącego zyżucia miescja na dysku w schemacie bronze
-- -----------------------------------------------------------------------------
create or replace view maintenance.v_bronze_obj_sizes as
SELECT
    c.relname                                               AS table_name,
    pg_size_pretty(pg_total_relation_size(c.oid))          AS total_size,
    pg_size_pretty(pg_relation_size(c.oid))                AS table_size,
    pg_size_pretty(pg_indexes_size(c.oid))                 AS indexes_size,
    pg_total_relation_size(c.oid)             AS total_size_num,
    pg_relation_size(c.oid)                   AS table_size_num,
    pg_indexes_size(c.oid)                    AS indexes_size_num
FROM pg_class c
JOIN pg_namespace ns ON ns.oid = c.relnamespace
WHERE ns.nspname = 'bronze'
  AND c.relkind = 'r'
  AND c.oid NOT IN (SELECT inhrelid  FROM pg_inherits)
  AND c.oid NOT IN (SELECT inhparent FROM pg_inherits)

UNION ALL

SELECT
    parent.relname                                                      AS table_name,
    pg_size_pretty(SUM(pg_total_relation_size(child.oid)))             AS total_size,
    pg_size_pretty(SUM(pg_relation_size(child.oid)))                   AS table_size,
    pg_size_pretty(SUM(pg_indexes_size(child.oid)))                    AS indexes_size,
    SUM(pg_total_relation_size(child.oid))             AS total_size_num,
    SUM(pg_relation_size(child.oid))                   AS table_size_num,
    SUM(pg_indexes_size(child.oid))                    AS indexes_size_num
FROM pg_inherits
JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
JOIN pg_class child  ON child.oid  = pg_inherits.inhrelid
JOIN pg_namespace ns ON ns.oid     = parent.relnamespace
WHERE ns.nspname = 'bronze'
GROUP BY parent.relname

ORDER BY table_name;





-- -----------------------------------------------------------------------------
-- Widok: silver.v_silver_obj_sizes 
-- OPIS:  Widok do analizy bieżącego zyżucia miescja na dysku w schemacie silver
-- -----------------------------------------------------------------------------
create or replace view maintenance.v_silver_obj_sizes as
SELECT
    c.relname                                               AS table_name,
    pg_size_pretty(pg_total_relation_size(c.oid))          AS total_size,
    pg_size_pretty(pg_relation_size(c.oid))                AS table_size,
    pg_size_pretty(pg_indexes_size(c.oid))                 AS indexes_size,
    pg_total_relation_size(c.oid)             AS total_size_num,
    pg_relation_size(c.oid)                   AS table_size_num,
    pg_indexes_size(c.oid)                    AS indexes_size_num
FROM pg_class c
JOIN pg_namespace ns ON ns.oid = c.relnamespace
WHERE ns.nspname = 'silver'
  AND c.relkind = 'r'
  AND c.oid NOT IN (SELECT inhrelid  FROM pg_inherits)
  AND c.oid NOT IN (SELECT inhparent FROM pg_inherits)

UNION ALL

SELECT
    parent.relname                                                      AS table_name,
    pg_size_pretty(SUM(pg_total_relation_size(child.oid)))             AS total_size,
    pg_size_pretty(SUM(pg_relation_size(child.oid)))                   AS table_size,
    pg_size_pretty(SUM(pg_indexes_size(child.oid)))                    AS indexes_size,
    SUM(pg_total_relation_size(child.oid))             AS total_size_num,
    SUM(pg_relation_size(child.oid))                   AS table_size_num,
    SUM(pg_indexes_size(child.oid))                    AS indexes_size_num
FROM pg_inherits
JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
JOIN pg_class child  ON child.oid  = pg_inherits.inhrelid
JOIN pg_namespace ns ON ns.oid     = parent.relnamespace
WHERE ns.nspname = 'silver'
GROUP BY parent.relname

ORDER BY table_name;



-- -----------------------------------------------------------------------------
-- Widok: gold.v_gold_obj_sizes 
-- OPIS:  Widok do analizy bieżącego zyżucia miescja na dysku w schemacie gold
-- -----------------------------------------------------------------------------
create or replace view maintenance.v_gold_obj_sizes as
SELECT
    c.relname                                               AS table_name,
    pg_size_pretty(pg_total_relation_size(c.oid))          AS total_size,
    pg_size_pretty(pg_relation_size(c.oid))                AS table_size,
    pg_size_pretty(pg_indexes_size(c.oid))                 AS indexes_size,
    pg_total_relation_size(c.oid)             AS total_size_num,
    pg_relation_size(c.oid)                   AS table_size_num,
    pg_indexes_size(c.oid)                    AS indexes_size_num
FROM pg_class c
JOIN pg_namespace ns ON ns.oid = c.relnamespace
WHERE ns.nspname = 'gold'
  AND c.relkind = 'r'
  AND c.oid NOT IN (SELECT inhrelid  FROM pg_inherits)
  AND c.oid NOT IN (SELECT inhparent FROM pg_inherits)

UNION ALL

SELECT
    parent.relname                                                      AS table_name,
    pg_size_pretty(SUM(pg_total_relation_size(child.oid)))             AS total_size,
    pg_size_pretty(SUM(pg_relation_size(child.oid)))                   AS table_size,
    pg_size_pretty(SUM(pg_indexes_size(child.oid)))                    AS indexes_size,
    SUM(pg_total_relation_size(child.oid))             AS total_size_num,
    SUM(pg_relation_size(child.oid))                   AS table_size_num,
    SUM(pg_indexes_size(child.oid))                    AS indexes_size_num
FROM pg_inherits
JOIN pg_class parent ON parent.oid = pg_inherits.inhparent
JOIN pg_class child  ON child.oid  = pg_inherits.inhrelid
JOIN pg_namespace ns ON ns.oid     = parent.relnamespace
WHERE ns.nspname = 'gold'
GROUP BY parent.relname

ORDER BY table_name;




-- -----------------------------------------------------------------------------
-- Widok: maintenance.v_total_obj_sizes 
-- OPIS:  Widok do analizy bieżącego zyżucia miescja na dysku we wszystkich schematach
-- -----------------------------------------------------------------------------
create or replace view maintenance.v_total_obj_sizes as
with t0 as
(
select 'Bronze' as schema
    , sum(total_size_num) as total_size 
    , sum(table_size_num) as table_size 
    , sum(indexes_size_num) as indexes_size 
from maintenance.v_bronze_obj_sizes
Union all
select 'Silver' as schema
    , sum(total_size_num) as total_size 
    , sum(table_size_num) as table_size 
    , sum(indexes_size_num) as indexes_size 
from maintenance.v_silver_obj_sizes
Union all
select 'Gold' as schema
    , sum(total_size_num) as total_size 
    , sum(table_size_num) as table_size 
    , sum(indexes_size_num) as indexes_size from maintenance.v_gold_obj_sizes
)

select schema
, pg_size_pretty(total_size) as total_size
, pg_size_pretty(table_size) as table_size
, pg_size_pretty(indexes_size) as indexes_size
, total_size as sort_size from t0
union 
select 'Total'
, pg_size_pretty(sum(total_size)) as total_size
, pg_size_pretty(sum(table_size)) as table_size
, pg_size_pretty(sum(indexes_size)) as indexes_size
, sum(total_size) as sort_size from t0
order by sort_size desc;
@echo off
cd /d %~dp0

:: Zmiana strony kodowej konsoli Windows na UTF-8 (65001)
chcp 65001 > nul

set PGPASSWORD=twoje_haslo
set PGHOST=localhost
set PGPORT=5432
set PGUSER=<user>
set PGDATABASE=<db_name>

:: Wymuszenie na narzędziu psql interpretowania plików jako UTF-8
set PGCLIENTENCODING=UTF-8

psql -U postgres -d job -f 01_schemas.sql
psql -U postgres -d job -f 02_bronze_tables.sql
psql -U postgres -d job -f 03_silver_tables.sql
psql -U postgres -d job -f 04_gold_tables.sql
psql -U postgres -d job -f 05_create_procedure_function.sql
psql -U postgres -d job -f 06_create_silver_views.sql
psql -U postgres -d job -f 07_insert_dim.sql
psql -U postgres -d job -f 08_create_gold_views.sql
psql -U postgres -d job -f 09_maintenance_tables.sql
psql -U postgres -d job -f 10_create_maintenance_views.sql
psql -U postgres -d job -f 99_create_other_objects.sql

echo Done!


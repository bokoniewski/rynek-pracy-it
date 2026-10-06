# airflow_prod/plugins/config.py
# Stałe konfiguracyjne pipeline'u
# Importowane przez wszystkie moduły tasków

import os

# ── Ścieżki ─────────────────────────────────────────────────────────────────

# Katalog główny projektu wewnątrz kontenera Docker
PROJECT_DIR  = "/opt/airflow"

# Katalog projektu DBT
DBT_DIR      = f"{PROJECT_DIR}/transform/project_job"

# Katalog z danymi raw (JSON ze scraperów)
DATA_RAW_DIR = f"{PROJECT_DIR}/data/raw"

# Katalog archiwum (JSON po przetworzeniu)
DATA_ARCHIVE_DIR = f"{PROJECT_DIR}/data/archive"

# ── Komendy DBT ──────────────────────────────────────────────────────────────

# Komenda DBT test
DBT_TEST_CMD = f"cd {DBT_DIR} && dbt test --profiles-dir ."

# Bazowa komenda DBT
DBT_CMD  = f"cd {DBT_DIR} && dbt run --profiles-dir ."

# XCom — pobieranie daty uruchomienia ustawionej przez set_run_date
# Używane w BashOperator jako zmienna bash FILE_DATE
GET_DATE = "FILE_DATE={{ ti.xcom_pull(task_ids='set_run_date') }}"

# ── Portale ──────────────────────────────────────────────────────────────────

# Portale w kolejności loadowania (sekwencyjnie)
PORTALS = ['pracuj', 'nofluff', 'joinit', 'protocol']

# ── Modele DBT gold ──────────────────────────────────────────────────────────

# Modele gold day (sekwencyjnie)
GOLD_DAY_MODELS = [
    "f_day_offers",
    "f_day_offers_benefit",
    "f_day_offers_loc",
    "f_day_offers_technology",
    "f_day_salaries",
]

# Modele gold month (równolegle po day)
GOLD_MONTH_MODELS = [
    "f_month_offers_agg",
    "f_month_offers_loc_agg",
    "f_month_salaries_agg",
]

# Modele gold year (równolegle po month)
GOLD_YEAR_MODELS = [
    "f_year_offers_agg",
    "f_year_offers_loc_agg",
    "f_year_salaries_agg",
]
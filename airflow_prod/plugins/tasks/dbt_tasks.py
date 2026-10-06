# airflow_prod/plugins/tasks/dbt_tasks.py
# Task uruchamiający dbt test silver jako bramka przed Gold
# Output z failed testów trafia do pipeline_run_step.error_details
# przez on_failure_callback — tak samo jak scrapery

import os
import subprocess
from config import DBT_TEST_CMD, DBT_DIR


def run_dbt_test_silver(**context):
    """
    Uruchamia dbt test dla wszystkich modeli Silver.
    Przechwytuje pełny output — failed testy trafiają do error_details
    w pipeline_run_step przez on_failure_callback.
    Zakres: tylko dane z bieżącego dnia (FILE_DATE z XCom).
    """
    file_date = context['ti'].xcom_pull(task_ids='set_run_date')

    cmd = (
        f"{DBT_TEST_CMD} "
        "--select silver_offers silver_offer_salaries "
        "silver_offer_technologies silver_offer_benefits silver_offer_locations "
        "silver_offer_modes silver_offer_levels silver_offer_contracts "
        "silver_offer_requirements silver_offer_responsibilities "
        "silver_offer_specs silver_offer_schedules "
        f'--vars \'{{"FILE_DATE": "{file_date}"}}\''
    )

    print(f"[dbt_test] Uruchamiam: {cmd}")

    result = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True,
        cwd=DBT_DIR
    )

    # Zawsze wypisz output do logów Airflow
    if result.stdout:
        print(f"[dbt_test] STDOUT:\n{result.stdout}")
    if result.stderr:
        print(f"[dbt_test] STDERR:\n{result.stderr}")

    if result.returncode != 0:
        # Wyciągnij tylko linie z FAIL żeby error_details był czytelny
        failed_lines = [
            line for line in result.stdout.split('\n')
            if 'FAIL' in line or 'Failure' in line or 'Error' in line
        ]
        failed_summary = '\n'.join(failed_lines) if failed_lines else result.stdout

        raise Exception(
            f"dbt test Silver zakończył się błędem (exit code {result.returncode}):\n\n"
            f"=== FAILED TESTS ===\n{failed_summary}\n\n"
            f"=== PEŁNY OUTPUT ===\n{result.stdout or 'brak'}\n\n"
            f"=== STDERR ===\n{result.stderr or 'brak'}"
        )

    print("[dbt_test] Wszystkie testy Silver przeszły pomyślnie.")
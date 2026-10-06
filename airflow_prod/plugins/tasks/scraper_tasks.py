# airflow_prod/plugins/tasks/scraper_tasks.py
# Funkcje uruchamiania scraperów jako PythonOperator
# Błędy trafiają do error_details w maintenance.pipeline_run_step

import os
import subprocess

from config import PROJECT_DIR


def run_scraper(scraper_name: str, **context):
    """
    Uruchamia scraper jako subprocess i przechwytuje pełny output.
    Dzięki temu błędy scrapera trafiają do error_details w pipeline_run_step
    zamiast generycznego "Bash command failed".

    Args:
        scraper_name: nazwa pliku scrapera bez rozszerzenia (np. 'pracuj', 'nofluff')
    """
    scraper_path = os.path.join(PROJECT_DIR, "scraper", "sites", f"{scraper_name}.py")

    print(f"[scraper] Uruchamiam: python {scraper_path}")

    result = subprocess.run(
        ["python", scraper_path],
        capture_output=True,
        text=True,
        cwd=PROJECT_DIR
    )

    # Zawsze wypisz output do logów Airflow
    if result.stdout:
        print(f"[scraper:{scraper_name}] STDOUT:\n{result.stdout}")
    if result.stderr:
        print(f"[scraper:{scraper_name}] STDERR:\n{result.stderr}")

    if result.returncode != 0:
        # Pełny błąd — trafi do error_details przez on_failure_callback
        raise Exception(
            f"Scraper '{scraper_name}' zakończył się błędem (exit code {result.returncode}):\n\n"
            f"=== STDOUT ===\n{result.stdout or 'brak'}\n\n"
            f"=== STDERR ===\n{result.stderr or 'brak'}"
        )

    print(f"[scraper] {scraper_name} zakończony pomyślnie.")
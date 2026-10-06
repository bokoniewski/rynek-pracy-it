# airflow_prod/plugins/tasks/loader_tasks.py
# Funkcje tasków loaderów
# Odpowiedzialne za wyszukiwanie plików JSON i uruchamianie loaderów

import os
import glob
import subprocess

from airflow.models import TaskInstance
from airflow.utils.session import create_session

from config import PROJECT_DIR, DATA_RAW_DIR


def find_and_cleanup_raw_file(portal: str, run_date: str) -> str:
    """
    Znajduje plik JSON dla danego portalu i daty w katalogu data/raw/{YYYYMMDD}/.
    Format nazwy pliku: {portal}_{YYYYMMDD}_*.json
    Jeśli znajdzie więcej niż jeden plik — usuwa duplikaty (zostawia najnowszy).
    Zwraca pełną ścieżkę do pliku.
    """
    # Zamień format daty z YYYY-MM-DD na YYYYMMDD (format w nazwie pliku i podfolderu)
    date_compact = run_date.replace('-', '')

    # Wzorzec wyszukiwania: np. data/raw/20260419/pracuj_20260419_*.json
    pattern = os.path.join(DATA_RAW_DIR, date_compact, f"{portal}_{date_compact}_*.json")
    matches = sorted(glob.glob(pattern))

    if not matches:
        raise FileNotFoundError(
            f"[find_raw_file] Nie znaleziono pliku JSON dla portalu '{portal}' "
            f"i daty '{run_date}'. Wzorzec: {pattern}"
        )

    if len(matches) > 1:
        # Zostaw najnowszy (ostatni po sortowaniu), usuń pozostałe
        print(f"[find_raw_file] Znaleziono {len(matches)} plików dla {portal} — czyszczę duplikaty.")
        for duplicate in matches[:-1]:
            os.remove(duplicate)
            print(f"[find_raw_file] Usunięto duplikat: {duplicate}")

    selected = matches[-1]
    print(f"[find_raw_file] Wybrany plik: {selected}")
    return selected


def load_portal(portal: str, **context):
    """
    Task loadera — uruchamia skrypt load_raw_{portal}.py
    z właściwym plikiem JSON znalezionym w data/raw/{YYYYMMDD}/.
    Sprawdza najpierw czy scraper dla tego portalu się powiódł.
    Jeśli scraper failed — pomija loader bez błędu (pipeline idzie dalej).
    """
    # Sprawdź stan tasku scrapera dla tego portalu
    with create_session() as session:
        ti = session.query(TaskInstance).filter(
            TaskInstance.dag_id == context['dag'].dag_id,
            TaskInstance.run_id == context['run_id'],
            TaskInstance.task_id == f"scrape_{portal}",
        ).first()
        scraper_failed = (ti.state != "success") if ti else True

    if scraper_failed:
        print(f"[load_{portal}] Scraper dla '{portal}' nie powiódł się — pomijam loader.")
        return  # Zakończ bez błędu — pipeline idzie dalej

    # Scraper OK — uruchom loader
    run_date = context['ti'].xcom_pull(task_ids='set_run_date')
    json_file = find_and_cleanup_raw_file(portal, run_date)

    loader_script = os.path.join(PROJECT_DIR, "loaders", f"load_raw_{portal}.py")
    cmd = ["python", loader_script, "--file", json_file]

    print(f"[load_{portal}] Uruchamiam: {' '.join(cmd)}")

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=PROJECT_DIR
    )

    print(result.stdout)
    if result.stderr:
        print(result.stderr)

    if result.returncode != 0:
        raise Exception(f"[load_{portal}] Loader zakończył się błędem:\n{result.stderr}")
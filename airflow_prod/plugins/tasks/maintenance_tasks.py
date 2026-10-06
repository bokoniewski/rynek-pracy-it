# airflow_prod/plugins/tasks/maintenance_tasks.py
# Funkcje tasków maintenance i archiwizacji
# Odpowiedzialne za czyszczenie tabel, indeksów i archiwizację plików JSON

import os
import shutil
from datetime import datetime
import glob

from db import get_db_connection
from config import PROJECT_DIR, DATA_RAW_DIR, DATA_ARCHIVE_DIR


def set_run_date(**context):
    """
    Task 0 — uruchamia się jako pierwszy.
    Pobiera aktualną datę i zapisuje do XCom.
    Tworzy rekord w maintenance.pipeline_run ze statusem PENDING.
    Wartość daty jest niezmenna przez cały czas trwania DAG run.
    """
    run_date   = datetime.today().strftime('%Y-%m-%d')
    dag_run_id = context['run_id']

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO maintenance.pipeline_run (run_date, dag_run_id, status)
                VALUES (%s, %s, 'PENDING')
                RETURNING id;
                """,
                (run_date, dag_run_id)
            )
            pipeline_run_id = cur.fetchone()[0]
            conn.commit()

        print(f"[set_run_date] Data uruchomienia pipeline: {run_date}")
        print(f"[set_run_date] Utworzono pipeline_run id={pipeline_run_id}")

        # Zapisz run_date i pipeline_run_id do XCom
        context['ti'].xcom_push(key='return_value', value=run_date)
        context['ti'].xcom_push(key='pipeline_run_id', value=pipeline_run_id)

        return run_date

    finally:
        conn.close()


def finalize_pipeline(**context):
    pipeline_run_id = context['ti'].xcom_pull(
        task_ids='set_run_date', key='pipeline_run_id'
    )
    if not pipeline_run_id:
        print("[finalize] Brak pipeline_run_id — pomijam.")
        return

    conn = get_db_connection()
    try:
        # Błędy krytyczne (nie scrapery)
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT COUNT(*) FROM maintenance.pipeline_run_step
                WHERE pipeline_run_id = %s
                  AND status = 'ERROR'
                  AND step_name NOT LIKE 'scrape_%%';
                """,
                (pipeline_run_id,)
            )
            critical_errors = cur.fetchone()[0]

        # Scrapery
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COUNT(*) FILTER (WHERE status = 'ERROR') AS failed,
                    COUNT(*)                                  AS total
                FROM maintenance.pipeline_run_step
                WHERE pipeline_run_id = %s
                  AND step_name LIKE 'scrape_%%';
                """,
                (pipeline_run_id,)
            )
            row            = cur.fetchone()
            scraper_errors = row[0] or 0
            total_scrapers = row[1] or 0

        # Logika statusu
        if critical_errors > 0 or (total_scrapers > 0 and scraper_errors == total_scrapers):
            final_status = 'ERROR'
        elif scraper_errors > 0:
            final_status = 'PARTIAL_SUCCESS'
        else:
            final_status = 'SUCCESS'

        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE maintenance.pipeline_run
                SET end_time = NOW(), status = %s
                WHERE id = %s;
                """,
                (final_status, pipeline_run_id)
            )
            conn.commit()

        print(f"[finalize] pipeline_run id={pipeline_run_id} → {final_status}")

    finally:
        conn.close()


def cleanup_database(**context):
    """
    Task końcowy — czyszczenie tabel i indeksów per rekord z maintenance.queue.
    Krok 1: CALL maintenance.p_build_queue() — buduje listę zadań
    Krok 2: Pobiera rekordy z maintenance.queue
    Krok 3: Wykonuje każdy sql_command po kolei
    """
    conn = get_db_connection()

    try:
        # Krok 1 — zbuduj kolejkę zadań
        with conn.cursor() as cur:
            print("[cleanup] Budowanie kolejki zadań...")
            cur.execute("CALL maintenance.p_build_queue();")
            conn.commit()

        # Krok 2 — pobierz wszystkie rekordy z kolejki
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, schema_name, object_name, sql_command "
                "FROM maintenance.queue ORDER BY id;"
            )
            tasks = cur.fetchall()
            print(f"[cleanup] Znaleziono {len(tasks)} zadań do wykonania.")

        # Krok 3 — wykonaj każde zadanie po kolei
        for task_id, schema_name, object_name, sql_command in tasks:
            print(f"[cleanup] Wykonuję ({task_id}): {sql_command}")
            try:
                with conn.cursor() as cur:
                    cur.execute(sql_command)
                    conn.commit()
                print(f"[cleanup] OK: {sql_command}")
            except Exception as e:
                conn.rollback()
                print(f"[cleanup] BŁĄD dla {schema_name}.{object_name}: {e}")
                # Kontynuuj mimo błędu — nie przerywaj całej kolejki

    finally:
        conn.close()
        print("[cleanup] Połączenie zamknięte.")


def archive_raw_data(**context):
    """
    Task końcowy — przenosi folder z dzisiejszymi plikami JSON do archiwum.
    data/raw/YYYYMMDD/ → data/archive/YYYY/MM/YYYYMMDD/
    Jeśli folder w archiwum już istnieje — nadpisuje go.
    """
    run_date    = context['ti'].xcom_pull(task_ids='set_run_date')
    date_compact = run_date.replace('-', '')
    year        = run_date[:4]
    month       = run_date[5:7]

    src = os.path.join(DATA_RAW_DIR, date_compact)
    dst = os.path.join(DATA_ARCHIVE_DIR, year, month, date_compact)

    if not os.path.exists(src):
        print(f"[archive] Folder źródłowy nie istnieje: {src} — pomijam.")
        return

    # Jeśli folder docelowy istnieje — usuń go przed przeniesieniem
    if os.path.exists(dst):
        shutil.rmtree(dst)
        print(f"[archive] Usunięto istniejący folder: {dst}")

    # Utwórz folder nadrzędny jeśli nie istnieje
    os.makedirs(os.path.dirname(dst), exist_ok=True)

    # Przenieś folder
    shutil.move(src, dst)
    print(f"[archive] Przeniesiono: {src} → {dst}")


def update_audit_bronze(**context):
    """
    Aktualizuje bronze.audit_file_log po udanym wgraniu danych do silver.offers.
    Wyszukuje pliki JSON z dysku dla bieżącego runu i dopasowuje do rekordów w bazie.
    Pomija pliki dla których records_total = 0 lub status != SUCCESS.
    """
    run_date     = context['ti'].xcom_pull(task_ids='set_run_date')
    date_compact = run_date.replace('-', '')

    # Znajdź pliki JSON na dysku dla bieżącego dnia
    pattern = os.path.join(DATA_RAW_DIR, date_compact, f"*_{date_compact}_*.json")
    json_files = glob.glob(pattern)

    if not json_files:
        print(f"[update_audit_bronze] Brak plików JSON dla daty {run_date} — pomijam.")
        return

    # Wyciągnij tylko nazwy plików (bez ścieżki)
    file_names = [os.path.basename(f) for f in json_files]
    print(f"[update_audit_bronze] Znalezione pliki: {file_names}")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE bronze.audit_file_log
                SET is_processed_to_silver = true,
                    processed_to_silver_at = NOW()
                WHERE file_name = ANY(%s)
                  AND records_total > 0
                  AND status in ('SUCCESS', 'SUCCESS_EMPTY')
                  AND is_processed_to_silver = false;
                """,
                (file_names,)
            )
            rows_updated = cur.rowcount
            conn.commit()
        print(f"[update_audit_bronze] Zaktualizowano {rows_updated} rekordów dla daty {run_date}")
    finally:
        conn.close()
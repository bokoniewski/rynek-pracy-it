# airflow_prod/plugins/audit.py
# Funkcje audytowe dla pipeline'u Airflow
# Rejestrują każdy krok w tabelach maintenance.pipeline_run i maintenance.pipeline_run_step
#
# Użycie w main_pipeline.py:
#   from audit import (
#       create_pipeline_run,
#       on_task_start,
#       on_task_success,
#       on_task_failure,
#       on_task_skipped,
#       finalize_pipeline_run,
#   )

import traceback
from datetime import datetime

from db import get_db_connection


# ── Funkcje głównej tabeli (pipeline_run) ────────────────────────────────────

def create_pipeline_run(**context) -> int:
    """
    Tworzy rekord w pipeline_run na starcie pipeline'u.
    Zapisuje run_id do XCom — używany przez wszystkie kolejne taski.
    Zwraca id nowego rekordu.
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

        print(f"[audit] Utworzono pipeline_run id={pipeline_run_id} dla dag_run_id={dag_run_id}")

        # Zapisz run_date i pipeline_run_id do XCom
        context['ti'].xcom_push(key='run_date', value=run_date)
        context['ti'].xcom_push(key='pipeline_run_id', value=pipeline_run_id)

        return pipeline_run_id

    finally:
        conn.close()


def finalize_pipeline_run(status: str, **context):
    """
    Aktualizuje rekord w pipeline_run na końcu pipeline'u.
    Ustawia end_time i status (SUCCESS lub ERROR).
    Wywoływana przez t_finalize task na końcu pipeline'u.
    """
    pipeline_run_id = context['ti'].xcom_pull(
        task_ids='set_run_date', key='pipeline_run_id'
    )

    if not pipeline_run_id:
        print("[audit] Brak pipeline_run_id w XCom — pomijam finalizację.")
        return

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE maintenance.pipeline_run
                SET end_time = NOW(),
                    status   = %s
                WHERE id = %s;
                """,
                (status, pipeline_run_id)
            )
            conn.commit()
        print(f"[audit] Zaktualizowano pipeline_run id={pipeline_run_id} → status={status}")
    finally:
        conn.close()


def finalize_pipeline_success(**context):
    """Callback dla pomyślnego zakończenia pipeline'u."""
    finalize_pipeline_run(status='SUCCESS', **context)


def finalize_pipeline_error(**context):
    """Callback dla błędnego zakończenia pipeline'u."""
    finalize_pipeline_run(status='ERROR', **context)


# ── Funkcje tabeli szczegółów (pipeline_run_step) ────────────────────────────

def _get_pipeline_run_id(context) -> int | None:
    """Pobiera pipeline_run_id z XCom."""
    return context['ti'].xcom_pull(
        task_ids='set_run_date', key='pipeline_run_id'
    )


def on_task_start(context):
    """
    Callback wywoływany na starcie każdego tasku (pre_execute).
    Tworzy rekord w pipeline_run_step ze statusem PENDING.
    """
    pipeline_run_id = _get_pipeline_run_id(context)
    if not pipeline_run_id:
        return

    step_name = context['task'].task_id

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO maintenance.pipeline_run_step
                    (pipeline_run_id, step_name, status)
                VALUES (%s, %s, 'PENDING');
                """,
                (pipeline_run_id, step_name)
            )
            conn.commit()
        print(f"[audit] Krok '{step_name}' → PENDING")
    finally:
        conn.close()


def on_task_success(context):
    """
    Callback wywoływany po pomyślnym zakończeniu tasku (on_success_callback).
    Aktualizuje rekord w pipeline_run_step → SUCCESS.
    """
    pipeline_run_id = _get_pipeline_run_id(context)
    if not pipeline_run_id:
        return

    step_name = context['task'].task_id

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE maintenance.pipeline_run_step
                SET end_time = NOW(),
                    status   = 'SUCCESS'
                WHERE pipeline_run_id = %s
                  AND step_name       = %s
                  AND status          = 'PENDING';
                """,
                (pipeline_run_id, step_name)
            )
            conn.commit()
        print(f"[audit] Krok '{step_name}' → SUCCESS")
    finally:
        conn.close()


def on_task_failure(context):
    """
    Callback wywoływany po błędzie tasku (on_failure_callback).
    Aktualizuje rekord w pipeline_run_step → ERROR + zapisuje error_details.
    """
    pipeline_run_id = _get_pipeline_run_id(context)
    if not pipeline_run_id:
        return

    step_name = context['task'].task_id

    # Zbierz szczegóły błędu
    exception     = context.get('exception')
    error_message = str(exception) if exception else "Nieznany błąd"
    error_tb      = ''.join(traceback.format_exception(
        type(exception), exception, exception.__traceback__
    )) if exception else ""

    error_details = (
        f"=== BŁĄD TASKU: {step_name} ===\n"
        f"Czas: {datetime.now()}\n"
        f"DAG run ID: {context.get('run_id', 'N/A')}\n"
        f"Wiadomość: {error_message}\n\n"
        f"=== STACK TRACE ===\n"
        f"{error_tb}"
    )

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE maintenance.pipeline_run_step
                SET end_time      = NOW(),
                    status        = 'ERROR',
                    error_details = %s
                WHERE pipeline_run_id = %s
                  AND step_name       = %s
                  AND status          = 'PENDING';
                """,
                (error_details, pipeline_run_id, step_name)
            )
            conn.commit()
        print(f"[audit] Krok '{step_name}' → ERROR")
    finally:
        conn.close()


def on_task_skipped(context):
    """
    Callback wywoływany gdy task jest pomijany (on_skipped_callback).
    Aktualizuje rekord w pipeline_run_step → SKIPPED.
    Używany np. gdy scraper failed i loader się pomija.
    """
    pipeline_run_id = _get_pipeline_run_id(context)
    if not pipeline_run_id:
        return

    step_name = context['task'].task_id

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE maintenance.pipeline_run_step
                SET end_time = NOW(),
                    status   = 'SKIPPED'
                WHERE pipeline_run_id = %s
                  AND step_name       = %s
                  AND status          = 'PENDING';
                """,
                (pipeline_run_id, step_name)
            )
            conn.commit()
        print(f"[audit] Krok '{step_name}' → SKIPPED")
    finally:
        conn.close()
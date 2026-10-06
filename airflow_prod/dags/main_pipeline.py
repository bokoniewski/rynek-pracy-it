# /dags/main_pipeline.py
# Główny pipeline orchestracji projektu job scraper
# Uruchamiany raz dziennie
#
# Przepływ:
# set_run_date           → tworzy rekord w pipeline_run (PENDING)
#   → [scrape_*]         (równolegle)
#     → load_*           (sekwencyjnie, trigger: all_done)
#       → dbt_silver_*   (trigger: all_done)
#         → t_pre_gold_schema (przygotowanie schematu dla gold)
#           → dbt_stg_gold_offers
#             → dbt_f_day_*     (sekwencyjnie)
#               → [dbt_f_month_*] (równolegle)
#                 → [dbt_f_year_*] (równolegle)
#                   → cleanup_database
#                     → archive_raw_data
#                       → finalize_pipeline  → aktualizuje pipeline_run (SUCCESS/ERROR)
#                         → prepare_report
#                           → send_report
#                           


from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.utils.trigger_rule import TriggerRule
from datetime import datetime, timedelta

# ── Importy z plugins/ ───────────────────────────────────────────────────────
from config import (
    PROJECT_DIR, DBT_CMD, GET_DATE,
    PORTALS,
    GOLD_DAY_MODELS, GOLD_MONTH_MODELS, GOLD_YEAR_MODELS,
)
from audit import on_task_start, on_task_success, on_task_failure, on_task_skipped
from tasks.loader_tasks import load_portal
from tasks.report_tasks import prepare_report
from tasks.send_report_tasks import send_report
from tasks.scraper_tasks import run_scraper
from tasks.dbt_tasks import run_dbt_test_silver

from tasks.maintenance_tasks import (
    set_run_date,
    cleanup_database,
    archive_raw_data,
    finalize_pipeline,
    update_audit_bronze,
)



t_prepare_report = PythonOperator(
    task_id="prepare_report",
    python_callable=prepare_report,
    trigger_rule=TriggerRule.ALL_DONE,
)

# ── Wspólne callbacki dla wszystkich tasków ──────────────────────────────────
# Podpinane do każdego tasku automatycznie przez default_args

default_args = {
    "pre_execute":          on_task_start,
    "on_success_callback":  on_task_success,
    "on_failure_callback":  on_task_failure,
    "on_skipped_callback":  on_task_skipped,
}


# ── Definicja DAG ────────────────────────────────────────────────────────────

with DAG(
    dag_id="main_pipeline_praca_IT",
    description="Pipeline: scraping → loading → DBT silver → DBT gold",
    start_date=datetime(2026, 5, 1),
    schedule="0 20 * * *",   # Codziennie o 20:00
    catchup=False,
    default_args=default_args,
    tags=["etl", "dbt", "scraper"],
) as dag:

    # ── Task 0: Ustaw datę uruchomienia + utwórz rekord audytowy ─────────────
    # Tworzy rekord w maintenance.pipeline_run ze statusem PENDING
    # Zapisuje run_date i pipeline_run_id do XCom

    t_set_run_date = PythonOperator(
        task_id="set_run_date",
        python_callable=set_run_date,
    )

    # ── Taski scraperów (równolegle) ─────────────────────────────────────────
    # pracuj używa undetected_chromedriver (uc) przez Selenium Grid
    # pozostałe używają standardowego Selenium przez Selenium Grid

    t_scrape_pracuj = PythonOperator(
    task_id="scrape_pracuj",
    python_callable=run_scraper,
    op_kwargs={"scraper_name": "pracuj"},
    )

    t_scrape_nofluff = PythonOperator(
        task_id="scrape_nofluff",
        python_callable=run_scraper,
        op_kwargs={"scraper_name": "nofluff"},
    )

    t_scrape_joinit = PythonOperator(
        task_id="scrape_joinit",
        python_callable=run_scraper,
        op_kwargs={"scraper_name": "joinit"},
    )

    t_scrape_protocol = PythonOperator(
        task_id="scrape_protocol",
        python_callable=run_scraper,
        op_kwargs={"scraper_name": "protocol"},
)

    scrape_tasks = [t_scrape_pracuj, t_scrape_nofluff, t_scrape_joinit, t_scrape_protocol]

    # ── Taski loaderów (sekwencyjnie) ────────────────────────────────────────
    # trigger_rule=ALL_DONE — loader uruchamia się nawet jeśli scraper failed
    # wewnątrz load_portal() sprawdzamy stan scrapera i pomijamy jeśli failed

    load_tasks = [
        PythonOperator(
            task_id=f"load_{portal}",
            python_callable=load_portal,
            op_kwargs={"portal": portal},
            trigger_rule=TriggerRule.ALL_DONE,
        )
        for portal in PORTALS
    ]

    # ── Taski DBT silver ─────────────────────────────────────────────────────
    # trigger_rule=ALL_DONE — DBT uruchamia się nawet jeśli jakiś loader failed

    t_dbt_silver_offers = BashOperator(
        task_id="dbt_silver_offers",
        bash_command=(
            f"{GET_DATE} && "
            f"{DBT_CMD} --select +silver_offers "
            '--vars \'{"FILE_DATE": "\'$FILE_DATE\'"}\''
        ),
    )

    t_dbt_silver_salaries = BashOperator(
        task_id="dbt_silver_salaries",
        bash_command=f"{DBT_CMD} --select silver_offer_salaries",
    )

    t_dbt_silver_rest = BashOperator(
        task_id="dbt_silver_rest",
        bash_command=(
            f"{DBT_CMD} --select "
            "silver_offer_benefits "
            "silver_offer_contracts "
            "silver_offer_levels "
            "silver_offer_locations "
            "silver_offer_modes "
            "silver_offer_requirements "
            "silver_offer_responsibilities "
            "silver_offer_schedules "
            "silver_offer_specs "
            "silver_offer_technologies"
        ),
    )

    t_update_audit_bronze = PythonOperator(
        task_id="update_audit_bronze",
        python_callable=update_audit_bronze,
    )

    # ── Task t_pre_gold_schema ──────────────────────────────────────────────
    # Uruchamiany po silver, przed gold
    # Wykonuje test danych silver przed wgraniem do gold
    
    t_dbt_test_silver = PythonOperator(
        task_id="dbt_test_silver",
        python_callable=run_dbt_test_silver,
    )

    # ── Task t_pre_gold_schema ──────────────────────────────────────────────
    # Uruchamiany po silver, przed gold
    # Przygotowuje strukturę bazodanową dla gold (partycje, wymiar dat)

    t_pre_gold_schema = PostgresOperator(
        task_id="pre_gold_schema",
        postgres_conn_id="postgres_main",
        sql="""
            CALL gold.load_d_date();
            CALL maintenance.p_create_partitions_table_for_date('gold', 'f_day_offers');
            CALL maintenance.p_create_partitions_table_for_date('gold', 'f_day_offers_loc');
        """,
    )

    # ── Task DBT stg gold ────────────────────────────────────────────────────

    t_dbt_stg_gold = BashOperator(
        task_id="dbt_stg_gold_offers",
        bash_command=(
            f"{GET_DATE} && "
            f"{DBT_CMD} --select stg_gold_offers "
            '--vars \'{"FILE_DATE": "\'$FILE_DATE\'"}\''
        ),
    )

    # ── Taski DBT gold day (sekwencyjnie) ────────────────────────────────────

    gold_day_tasks = [
        BashOperator(
            task_id=f"dbt_{model}",
            bash_command=f"{DBT_CMD} --select {model}",
        )
        for model in GOLD_DAY_MODELS
    ]

    # ── Taski DBT gold month (równolegle po zakończeniu wszystkich day) ───────

    gold_month_tasks = [
        BashOperator(
            task_id=f"dbt_{model}",
            bash_command=f"{DBT_CMD} --select {model}",
        )
        for model in GOLD_MONTH_MODELS
    ]

    # ── Taski DBT gold year (równolegle po zakończeniu wszystkich month) ──────

    gold_year_tasks = [
        BashOperator(
            task_id=f"dbt_{model}",
            bash_command=f"{DBT_CMD} --select {model}",
        )
        for model in GOLD_YEAR_MODELS
    ]

    # ── Task cleanup per rekord ──────────────────────────────────────────────
    # Buduje kolejkę zadań i wykonuje VACUUM FULL per rekord z maintenance.queue

    t_cleanup = PythonOperator(
        task_id="cleanup_database",
        python_callable=cleanup_database,
    )

    # ── Task archiwizacji plików JSON ────────────────────────────────────────
    # Przenosi folder data/raw/YYYYMMDD/ do data/archive/YYYY/MM/YYYYMMDD/

    t_archive = PythonOperator(
        task_id="archive_raw_data",
        python_callable=archive_raw_data,
    )

    # ── Task przygotowania raportu ───────────────────────────────────────────
    t_send_report = PythonOperator(
        task_id="send_report",
        python_callable=send_report,
        trigger_rule=TriggerRule.ALL_DONE,
    )

    # ── Task finalizacji pipeline'u ──────────────────────────────────────────
    # Aktualizuje pipeline_run → SUCCESS lub ERROR
    # Uruchamiany zawsze (trigger: ALL_DONE) nawet jeśli poprzednie taski failed

    t_finalize = PythonOperator(
        task_id="finalize_pipeline",
        python_callable=finalize_pipeline,
        trigger_rule=TriggerRule.ALL_DONE,
    )

    # ── Zależności ───────────────────────────────────────────────────────────

    # set_run_date → wszystkie scrapery równolegle
    t_set_run_date >> scrape_tasks

    # Czekaj aż WSZYSTKIE scrapery się zakończą → dopiero wtedy pierwszy loader
    scrape_tasks >> load_tasks[0]

    # Loadery sekwencyjnie między sobą
    for i in range(len(load_tasks) - 1):
        load_tasks[i] >> load_tasks[i + 1]

    # Ostatni loader → silver pipeline sekwencyjnie
    load_tasks[-1] >> t_dbt_silver_offers
    t_dbt_silver_offers >> t_dbt_silver_salaries >> t_dbt_silver_rest >> t_update_audit_bronze

    # silver → t_update_audit_bronze → t_pre_gold_schema → stg gold
    t_update_audit_bronze >> t_dbt_test_silver >> t_pre_gold_schema >> t_dbt_stg_gold

    # stg gold → gold day sekwencyjnie
    t_dbt_stg_gold >> gold_day_tasks[0]
    for i in range(len(gold_day_tasks) - 1):
        gold_day_tasks[i] >> gold_day_tasks[i + 1]

    # ostatni day → wszystkie month równolegle
    gold_day_tasks[-1] >> gold_month_tasks

    # wszystkie month muszą się skończyć → dopiero wtedy wszystkie year równolegle
    for month_task in gold_month_tasks:
        month_task >> gold_year_tasks

    # wszystkie year → cleanup → archive → finalize
    for year_task in gold_year_tasks:
        year_task >> t_cleanup

    t_cleanup >> t_archive >> t_finalize >> t_prepare_report >> t_send_report
"""
=============================================================================
LOADER: load_raw_joinit.py
PROJEKT: Project_job
WARSTWA: Bronze
ŹRÓDŁO:  justjoin.it – pliki JSON ze scrapera
=============================================================================
"""

import json
import argparse
from pathlib import Path

from psycopg2.extras import execute_values

from loader_base import (
    LoadStats,
    get_connection,
    extract_date_from_filename,
    create_audit_log,
    update_audit_log,
    setup_loader_logger,
)

logger = setup_loader_logger(__name__)


# =============================================================================
# MAPOWANIE JSON → KOLUMNY TABELI
# =============================================================================

def map_record(record: dict, file_id: int) -> tuple:
    """
    Mapuje pojedynczy rekord z JSON na tuple zgodny z kolejnością kolumn INSERT.
    Obsługuje zagnieżdżone obiekty:
    - location  → rozbity na location_city, location_region itd.
    - salary    → serializowany jako JSONB
    - tech_stack → serializowany do JSONB
    """
    location      = record.get("location") or {}
    date_posted   = record.get("date_posted")
    valid_through = record.get("valid_through")
    date_posted   = None if date_posted   in (None, "N/A") else date_posted
    valid_through = None if valid_through in (None, "N/A") else valid_through

    return (
        file_id,
        record.get("portal"),
        str(record.get("id", "")),
        record.get("url"),
        record.get("title"),
        date_posted,
        valid_through,
        record.get("employer"),
        record.get("employer_url"),
        record.get("specialization"),
        location.get("city"),
        location.get("region"),
        location.get("street"),
        location.get("postal_code"),
        location.get("country"),
        record.get("remote"),
        record.get("job_schedule"),
        record.get("job_contract"),
        record.get("seniority"),
        record.get("job_mode"),
        record.get("employment_type"),
        json.dumps(record.get("tech_stack"),  ensure_ascii=False),
        json.dumps(record.get("salary_list"), ensure_ascii=False),
        record.get("description"),
    )


# =============================================================================
# GŁÓWNA FUNKCJA LOADERA
# =============================================================================

def load_offers_to_bronze(file_path: str) -> LoadStats:
    """
    Główna funkcja ładująca oferty z pliku JSON do bronze.raw_offers_joinit.
    """
    source_file = Path(file_path).name

    if not source_file.startswith("joinit_"):
        raise ValueError(f"Nieprawidłowy plik: '{source_file}'. Loader obsługuje tylko pliki 'joinit_*.json'")

    file_date = extract_date_from_filename(source_file)
    logger.info(f"Start ładowania pliku: {source_file} (data: {file_date})")

    with open(file_path, "r", encoding="utf-8") as f:
        records = json.load(f)

    total = len(records)
    logger.info(f"Wczytano {total} rekordów z pliku")

    if total == 0:
        logger.warning("Plik jest pusty – brak rekordów do załadowania")
        stats = LoadStats(total=0, inserted=0, skipped=0, errors=0)
        return stats

    file_id = create_audit_log(source_file, file_date, total)
    if file_id is None:
        raise RuntimeError("Nie udało się utworzyć rekordu audit log – przerywam ładowanie")

    conn     = None
    inserted = 0
    skipped  = 0
    errors   = 0

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        incoming_ids = [str(r.get("id", "")) for r in records]
        cursor.execute(
            """
            SELECT offer_id FROM bronze.raw_offers_joinit
            WHERE offer_id = ANY(%s)
              AND loaded_at::date BETWEEN %s::date - INTERVAL '30 days'
                                      AND %s::date + INTERVAL '30 days'
            """,
            (incoming_ids, file_date, file_date)
        )
        existing_ids = {row[0] for row in cursor.fetchall()}

        if existing_ids:
            logger.info(f"Znaleziono {len(existing_ids)} duplikatów – zostaną pominięte")

        new_records = [
            r for r in records
            if str(r.get("id", "")) not in existing_ids
            and r.get("date_posted") is not None
        ]
        skipped = total - len(new_records)

        if not new_records:
            logger.info("Brak nowych rekordów – wszystkie już istnieją w bazie")
            stats = LoadStats(total=total, inserted=0, skipped=skipped, errors=0)
            return stats

        rows = []
        for record in new_records:
            try:
                rows.append(map_record(record, file_id))
            except Exception as e:
                logger.error(f"Błąd mapowania rekordu id={record.get('id')}: {e}")
                errors += 1

        insert_sql = """
            INSERT INTO bronze.raw_offers_joinit (
                source_file_id, portal, offer_id, url, title,
                date_posted, valid_through, employer, employer_url,
                specialization, location_city, location_region,
                location_street, location_postal_code, location_country,
                remote, job_schedule, job_contract, seniority,
                job_mode, employment_type, tech_stack, salary, description
            ) VALUES %s
        """
        execute_values(cursor, insert_sql, rows, page_size=500)
        conn.commit()

        inserted = len(rows)
        logger.info(f"Bulk insert zakończony: {inserted} rekordów wstawionych")

    except Exception as e:
        logger.error(f"Krytyczny błąd podczas ładowania: {e}")
        if conn:
            conn.rollback()
        errors = total - skipped
        raise

    finally:
        if conn:
            conn.close()
        stats = LoadStats(total=total, inserted=inserted, skipped=skipped, errors=errors)
        stats.log_summary(logger)
        update_audit_log(file_id, stats)

    return stats


# =============================================================================
# URUCHOMIENIE BEZPOŚREDNIE
# =============================================================================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Loader: bronze.raw_offers_joinit")
    parser.add_argument("--file", required=True, help="Ścieżka do pliku JSON")
    args   = parser.parse_args()
    result = load_offers_to_bronze(file_path=args.file)
    print(result)
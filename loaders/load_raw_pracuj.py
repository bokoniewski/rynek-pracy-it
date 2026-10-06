"""
=============================================================================
LOADER: load_raw_pracuj.py
PROJEKT: Project_job
WARSTWA: Bronze
ŹRÓDŁO:  pracuj.pl – pliki JSON ze scrapera
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
    Klucz "ID" (JSON) → offer_id (tabela).
    Pola JSONB serializowane do stringa.
    """
    return (
        file_id,
        str(record.get("ID", "")),
        record.get("url"),
        record.get("title"),
        record.get("employer"),
        record.get("employer_address"),
        record.get("job_workplace"),
        record.get("job_contract"),
        record.get("job_schedule"),
        record.get("employment_type"),
        record.get("job_modes"),
        record.get("specialization"),
        json.dumps(record.get("salary_info"),           ensure_ascii=False),
        json.dumps(record.get("technology_expected"),   ensure_ascii=False),
        json.dumps(record.get("technology_optional"),   ensure_ascii=False),
        json.dumps(record.get("responsibilities"),      ensure_ascii=False),
        json.dumps(record.get("requirements_expected"), ensure_ascii=False),
        json.dumps(record.get("requirements_optional"), ensure_ascii=False),
        json.dumps(record.get("offered"),               ensure_ascii=False),
        json.dumps(record.get("benefits"),              ensure_ascii=False),
    )


# =============================================================================
# GŁÓWNA FUNKCJA LOADERA
# =============================================================================

def load_offers_to_bronze(file_path: str) -> LoadStats:
    """
    Główna funkcja ładująca oferty z pliku JSON do bronze.raw_offers_pracuj.
    """
    source_file = Path(file_path).name

    if not source_file.startswith("pracuj_"):
        raise ValueError(f"Nieprawidłowy plik: '{source_file}'. Loader obsługuje tylko pliki 'pracuj_*.json'")

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
        conn    = get_connection()
        cursor  = conn.cursor()

        incoming_ids = [str(r.get("ID", "")) for r in records]
        cursor.execute(
            """
            SELECT offer_id FROM bronze.raw_offers_pracuj
            WHERE offer_id = ANY(%s)
              AND loaded_at::date BETWEEN %s::date - INTERVAL '30 days'
                                      AND %s::date + INTERVAL '30 days'
            """,
            (incoming_ids, file_date, file_date)
        )
        existing_ids = {row[0] for row in cursor.fetchall()}

        if existing_ids:
            logger.info(f"Znaleziono {len(existing_ids)} duplikatów – zostaną pominięte")

        new_records = [r for r in records if str(r.get("ID", "")) not in existing_ids]
        skipped     = total - len(new_records)

        if not new_records:
            logger.info("Brak nowych rekordów – wszystkie już istnieją w bazie")
            stats = LoadStats(total=total, inserted=0, skipped=skipped, errors=0)
            return stats

        rows = []
        for record in new_records:
            try:
                rows.append(map_record(record, file_id))
            except Exception as e:
                logger.error(f"Błąd mapowania rekordu ID={record.get('ID')}: {e}")
                errors += 1

        insert_sql = """
            INSERT INTO bronze.raw_offers_pracuj (
                source_file_id, offer_id, url, title, employer,
                employer_address, job_workplace, job_contract, job_schedule,
                employment_type, job_modes, specialization, salary_info,
                technology_expected, technology_optional, responsibilities,
                requirements_expected, requirements_optional, offered, benefits
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
    parser = argparse.ArgumentParser(description="Loader: bronze.raw_offers_pracuj")
    parser.add_argument("--file", required=True, help="Ścieżka do pliku JSON")
    args   = parser.parse_args()
    result = load_offers_to_bronze(file_path=args.file)
    print(result)
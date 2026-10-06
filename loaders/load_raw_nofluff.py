"""
=============================================================================
LOADER: load_raw_nofluff.py
PROJEKT: Project_job
WARSTWA: Bronze
ŹRÓDŁO:  nofluffjobs.com – pliki JSON ze scrapera
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
    Klucz "id" (JSON) → offer_id (tabela).
    Pola JSONB serializowane do stringa.
    """
    return (
        file_id,
        str(record.get("id", "")),
        record.get("url"),
        json.dumps(record.get("specialization"),            ensure_ascii=False),
        record.get("job_title"),
        record.get("job_level"),
        record.get("job_modes"),
        record.get("job_modes_2"),
        record.get("employer"),
        json.dumps(record.get("employer_address"),          ensure_ascii=False),
        json.dumps(record.get("salary_info"),               ensure_ascii=False),
        json.dumps(record.get("technology_expected"),       ensure_ascii=False),
        json.dumps(record.get("technology_optional"),       ensure_ascii=False),
        json.dumps(record.get("requirements_expected"),     ensure_ascii=False),
        json.dumps(record.get("requirements_optional"),     ensure_ascii=False),
        json.dumps(record.get("responsibilities"),          ensure_ascii=False),
        json.dumps(record.get("details_responsibilities"),  ensure_ascii=False),
        json.dumps(record.get("office_benefits"),           ensure_ascii=False),
        json.dumps(record.get("benefits"),                  ensure_ascii=False),
    )


# =============================================================================
# GŁÓWNA FUNKCJA LOADERA
# =============================================================================

def load_offers_to_bronze(file_path: str) -> LoadStats:
    """
    Główna funkcja ładująca oferty z pliku JSON do bronze.raw_offers_nofluff.
    """
    source_file = Path(file_path).name

    if not source_file.startswith("nofluff_"):
        raise ValueError(f"Nieprawidłowy plik: '{source_file}'. Loader obsługuje tylko pliki 'nofluff_*.json'")

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
            SELECT offer_id FROM bronze.raw_offers_nofluff
            WHERE offer_id = ANY(%s)
              AND loaded_at::date BETWEEN %s::date - INTERVAL '30 days'
                                      AND %s::date + INTERVAL '30 days'
            """,
            (incoming_ids, file_date, file_date)
        )
        existing_ids = {row[0] for row in cursor.fetchall()}

        if existing_ids:
            logger.info(f"Znaleziono {len(existing_ids)} duplikatów – zostaną pominięte")

        new_records = [r for r in records if str(r.get("id", "")) not in existing_ids]
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
                logger.error(f"Błąd mapowania rekordu id={record.get('id')}: {e}")
                errors += 1

        insert_sql = """
            INSERT INTO bronze.raw_offers_nofluff (
                source_file_id, offer_id, url, specialization,
                job_title, job_level, job_modes, job_modes_2,
                employer, employer_address, salary_info,
                technology_expected, technology_optional,
                requirements_expected, requirements_optional,
                responsibilities, details_responsibilities,
                office_benefits, benefits
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
    parser = argparse.ArgumentParser(description="Loader: bronze.raw_offers_nofluff")
    parser.add_argument("--file", required=True, help="Ścieżka do pliku JSON")
    args   = parser.parse_args()
    result = load_offers_to_bronze(file_path=args.file)
    print(result)
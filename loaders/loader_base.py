# loaders/loader_base.py
# Wspólne funkcje dla wszystkich loaderów
# Importowane przez: load_raw_pracuj.py, load_raw_nofluff.py,
#                    load_raw_joinit.py, load_raw_protocol.py

import os
import re
import logging
from dataclasses import dataclass, field
from pathlib import Path

import psycopg2
import psycopg2.extensions
from dotenv import load_dotenv

from scraper.utils import setup_logger


# =============================================================================
# LOGGER
# =============================================================================

def setup_loader_logger(name: str, log_file: str = "loaders/logs/loader.log") -> logging.Logger:
    return setup_logger(name, log_file=log_file)


# =============================================================================
# STATYSTYKI ŁADOWANIA
# =============================================================================

@dataclass
class LoadStats:
    total:    int = 0
    inserted: int = 0
    skipped:  int = 0
    errors:   int = 0

    @property
    def status(self) -> str:
        if self.errors > 0:
            return "ERROR"
        if self.inserted == 0:
            return "SUCCESS_EMPTY"
        return "SUCCESS"

    def log_summary(self, logger: logging.Logger = None) -> None:
        msg = (
            f"Podsumowanie [{self.status}] | "
            f"total: {self.total} | "
            f"inserted: {self.inserted} | "
            f"skipped: {self.skipped} | "
            f"errors: {self.errors}"
        )
        if logger:
            logger.info(msg)
        else:
            print(msg)


# =============================================================================
# POŁĄCZENIE Z BAZĄ DANYCH
# =============================================================================

def get_connection() -> psycopg2.extensions.connection:
    """
    Tworzy połączenie z bazą PostgreSQL.
    Dane połączenia pobierane z config/.env lub zmiennych środowiskowych.
    """
    env_path = Path(__file__).resolve().parent.parent / "config" / ".env"
    load_dotenv(dotenv_path=env_path)

    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", 5432),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD")
    )


# =============================================================================
# FUNKCJA POMOCNICZA – WYCIĄGANIE DATY Z NAZWY PLIKU
# =============================================================================

def extract_date_from_filename(filename: str) -> str | None:
    """
    Wyciąga datę z nazwy pliku.
    Przykład: 'pracuj_20260315_164131.json' → '2026-03-15'
    """
    match = re.search(r'(\d{4})(\d{2})(\d{2})_\d{6}', filename)
    if match:
        return f"{match.group(1)}-{match.group(2)}-{match.group(3)}"
    return None


# =============================================================================
# AUDIT LOG – KROK 1: Utwórz rekord IN_PROGRESS, zwróć file_id
# =============================================================================

def create_audit_log(source_file: str, file_date: str | None, total: int) -> int | None:
    """
    Tworzy rekord audytu ze statusem IN_PROGRESS przed startem ładowania.
    Zwraca file_id który będzie użyty jako FK w tabeli bronze.raw_offers_*.
    """
    conn = None
    try:
        conn = get_connection()
        with conn.cursor() as cur:

            # Wyciągnij nazwę portalu z nazwy pliku (np. 'pracuj' z 'pracuj_20260315.json')
            portal_match = re.match(r'^([a-z]+)_', source_file)
            portal = portal_match.group(1) if portal_match else source_file

            cur.execute(
                """
                INSERT INTO bronze.audit_file_log
                    (file_name, portal, file_date, records_total, status)
                VALUES (%s, %s, %s, %s, 'IN_PROGRESS')
                RETURNING file_id;
                """,
                (source_file, portal, file_date, total)
            )
            file_id = cur.fetchone()[0]
            conn.commit()
            return file_id

    except Exception as e:
        if conn:
            conn.rollback()
        logging.error(f"Błąd tworzenia audit log: {e}")
        return None
    finally:
        if conn:
            conn.close()


# =============================================================================
# AUDIT LOG – KROK 3: Zaktualizuj rekord o finalne statystyki
# =============================================================================

def update_audit_log(file_id: int, stats: LoadStats) -> None:
    """
    Aktualizuje rekord audytu po zakończeniu ładowania.
    Ustawia finalne statystyki i status (SUCCESS / SUCCESS_EMPTY / ERROR).
    """
    conn = None
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE bronze.audit_file_log
                SET records_inserted = %s,
                    records_skipped  = %s,
                    records_errors   = %s,
                    status           = %s,
                    loaded_at        = NOW()
                WHERE file_id = %s;
                """,
                (stats.inserted, stats.skipped, stats.errors, stats.status, file_id)
            )
            conn.commit()

    except Exception as e:
        if conn:
            conn.rollback()
        logging.error(f"Błąd aktualizacji audit log: {e}")
    finally:
        if conn:
            conn.close()
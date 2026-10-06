# airflow_prod/plugins/db.py
# Uniwersalna funkcja połączenia z bazą PostgreSQL
# Importowana przez wszystkie moduły wymagające dostępu do bazy

import os
import psycopg2


def get_db_connection():
    """
    Uniwersalna funkcja do łączenia się z bazą PostgreSQL.
    Dane połączenia pobierane ze zmiennych środowiskowych ustawionych w docker-compose.yaml.
    """
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=os.environ.get("DB_PORT", 5432),
        dbname=os.environ.get("DB_NAME"),
        user=os.environ.get("DB_USER"),
        password=os.environ.get("DB_PASSWORD"),
    )
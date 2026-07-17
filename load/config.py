"""Database connection settings, loaded from .env."""
import os

from dotenv import load_dotenv
import psycopg2

load_dotenv()

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     os.getenv("DB_PORT", "5432"),
    "dbname":   os.getenv("DB_NAME", "olist"),
    "user":     os.getenv("DB_USER", ""),
    "password": os.getenv("DB_PASSWORD", ""),
}

RAW_SCHEMA = os.getenv("DB_SCHEMA", "raw")


def get_connection():
    return psycopg2.connect(**DB_CONFIG)

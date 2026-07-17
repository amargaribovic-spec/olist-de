"""
Load the Olist CSVs into the raw schema.

    python load/load_raw.py --create   # create schema + tables, then load
    python load/load_raw.py            # reload data only
"""
import os
import argparse

from config import get_connection, RAW_SCHEMA

HERE     = os.path.dirname(__file__)
DATA_DIR = os.path.join(HERE, "..", "data", "raw")
DDL_PATH = os.path.join(HERE, "..", "sql", "ddl", "01_raw_schema.sql")

CSV_TO_TABLE = {
    "olist_orders_dataset.csv":              "orders",
    "olist_order_items_dataset.csv":         "order_items",
    "olist_order_payments_dataset.csv":      "order_payments",
    "olist_order_reviews_dataset.csv":       "order_reviews",
    "olist_customers_dataset.csv":           "customers",
    "olist_sellers_dataset.csv":             "sellers",
    "olist_products_dataset.csv":            "products",
    "product_category_name_translation.csv": "product_category_translation",
    "olist_geolocation_dataset.csv":         "geolocation",
}


def run_ddl(conn):
    with open(DDL_PATH, "r", encoding="utf-8") as f:
        ddl = f.read()
    with conn.cursor() as cur:
        cur.execute(ddl)
    conn.commit()
    print("Raw schema and tables ready.")


def load_csv(conn, csv_file, table):
    path = os.path.join(DATA_DIR, csv_file)
    if not os.path.exists(path):
        print(f"  skip (not found): {csv_file}")
        return

    full_table = f"{RAW_SCHEMA}.{table}"
    with conn.cursor() as cur:
        cur.execute(f"TRUNCATE {full_table};")   # truncate + reload keeps the load idempotent
        with open(path, "r", encoding="utf-8") as f:
            cur.copy_expert(
                f"COPY {full_table} FROM STDIN WITH (FORMAT csv, HEADER true)", f
            )
        cur.execute(f"SELECT count(*) FROM {full_table};")
        n_rows = cur.fetchone()[0]
    conn.commit()
    print(f"  {full_table:<38} {n_rows:>9,} rows")


def main():
    parser = argparse.ArgumentParser(description="Load Olist CSVs into the raw schema.")
    parser.add_argument("--create", action="store_true",
                        help="create the schema and tables before loading")
    args = parser.parse_args()

    conn = get_connection()
    try:
        if args.create:
            run_ddl(conn)
        for csv_file, table in CSV_TO_TABLE.items():
            load_csv(conn, csv_file, table)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

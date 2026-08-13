"""
Load Olist CSVs into the raw landing schema.

    python load/load_raw.py --full      # clean rebuild → the ORIGINAL Olist data only:
                                        # (re)create schema, truncate, load the 9
                                        # canonical CSVs.
    python load/load_raw.py --append    # incremental: load only NEW batch files from
                                        # data/incoming/ (skips anything already loaded)

Raw is append-only. Each row is stamped with _loaded_at; each file is recorded in
raw._load_ledger (by sha256) so re-running --append never double-loads.

Batch files live in data/incoming/ and are named "<table>__<label>.csv" (see
generate_fake_batch.py). After loading they move to data/processed/.
"""
import os
import glob
import shutil
import hashlib
import argparse

from config import get_connection, RAW_SCHEMA

HERE          = os.path.dirname(__file__)
# Data root is configurable (OLIST_DATA_DIR) so CI / tests can point at a
# throwaway directory instead of the repo's data/.
DATA_DIR      = os.environ.get("OLIST_DATA_DIR") or os.path.join(HERE, "..", "data")
RAW_DIR       = os.path.join(DATA_DIR, "raw")
INCOMING_DIR  = os.path.join(DATA_DIR, "incoming")
PROCESSED_DIR = os.path.join(DATA_DIR, "processed")
DDL_PATH      = os.path.join(HERE, "..", "sql", "ddl", "01_raw_schema.sql")

# The canonical seed CSVs (initial full dataset) → raw table.
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
KNOWN_TABLES = set(CSV_TO_TABLE.values())


def run_ddl(conn):
    with open(DDL_PATH, "r", encoding="utf-8") as f:
        ddl = f.read()
    with conn.cursor() as cur:
        cur.execute(ddl)
    conn.commit()
    print("Raw schema, tables and load ledger ready.")


def file_sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def data_columns(conn, table):
    """Table's data columns in order, excluding the _loaded_at metadata column."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s AND column_name <> '_loaded_at'
            ORDER BY ordinal_position
            """,
            (RAW_SCHEMA, table),
        )
        return [r[0] for r in cur.fetchall()]


def already_loaded(conn, sha):
    with conn.cursor() as cur:
        cur.execute("SELECT 1 FROM raw._load_ledger WHERE file_sha256 = %s LIMIT 1", (sha,))
        return cur.fetchone() is not None


def truncate(conn, table):
    with conn.cursor() as cur:
        cur.execute(f"TRUNCATE {RAW_SCHEMA}.{table};")
    conn.commit()


def load_file(conn, path, table):
    """COPY one CSV into its raw table (append). Header row is skipped; data
    columns load positionally, _loaded_at defaults to now(). Records the ledger."""
    cols = data_columns(conn, table)
    col_list = ", ".join(cols)
    full_table = f"{RAW_SCHEMA}.{table}"
    with conn.cursor() as cur:
        with open(path, "r", encoding="utf-8") as f:
            cur.copy_expert(
                f"COPY {full_table} ({col_list}) FROM STDIN WITH (FORMAT csv, HEADER true)", f
            )
        n_rows = cur.rowcount
        cur.execute(
            "INSERT INTO raw._load_ledger (source_file, table_name, row_count, file_sha256) "
            "VALUES (%s, %s, %s, %s)",
            (os.path.basename(path), table, n_rows, file_sha256(path)),
        )
    conn.commit()
    print(f"  {full_table:<38} +{n_rows:>8,} rows  ({os.path.basename(path)})")
    return n_rows


def batch_files(directory):
    """Batch CSVs named '<table>__<label>.csv' → (path, table), for known tables."""
    out = []
    for path in sorted(glob.glob(os.path.join(directory, "*.csv"))):
        table = os.path.basename(path).split("__", 1)[0]
        if table in KNOWN_TABLES:
            out.append((path, table))
        else:
            print(f"  skip (unknown table prefix): {os.path.basename(path)}")
    return out


def move_to_processed(path):
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    shutil.move(path, os.path.join(PROCESSED_DIR, os.path.basename(path)))


def load_batches(conn, directory, move=True):
    """Append every not-yet-loaded batch file in a directory."""
    loaded = 0
    for path, table in batch_files(directory):
        if already_loaded(conn, file_sha256(path)):
            print(f"  skip (already loaded): {os.path.basename(path)}")
            if move:
                move_to_processed(path)
            continue
        load_file(conn, path, table)
        loaded += 1
        if move:
            move_to_processed(path)
    return loaded


def cmd_full(conn):
    """Clean rebuild → the original Olist dataset (the 9 canonical CSVs).

    Restores the pristine baseline and nothing else, so every fresh rebuild is
    identical. Batches are added on demand afterwards via --append."""
    run_ddl(conn)
    print("Truncating raw tables + ledger...")
    for table in KNOWN_TABLES:
        truncate(conn, table)
    with conn.cursor() as cur:
        cur.execute("TRUNCATE raw._load_ledger RESTART IDENTITY;")
    conn.commit()

    print("Loading canonical CSVs (original Olist data)...")
    for csv_file, table in CSV_TO_TABLE.items():
        path = os.path.join(RAW_DIR, csv_file)
        if os.path.exists(path):
            load_file(conn, path, table)
        else:
            print(f"  skip (not found): {csv_file}")
    print("Baseline only — batches are added on demand via --append.")


def cmd_append(conn):
    """Incremental → load only new batch files from data/incoming/."""
    run_ddl(conn)   # ensure schema/ledger exist
    print("Appending new batches from data/incoming/...")
    n = load_batches(conn, INCOMING_DIR, move=True)
    print("No new batch files." if n == 0 else f"Appended {n} batch file(s).")


def main():
    parser = argparse.ArgumentParser(description="Load Olist CSVs into the raw schema.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--full", action="store_true",
                       help="clean rebuild (default): recreate, truncate, load the "
                            "original 9 canonical CSVs only")
    group.add_argument("--append", action="store_true",
                       help="incremental: load only new batches from data/incoming/")
    args = parser.parse_args()

    conn = get_connection()
    try:
        if args.append:
            cmd_append(conn)
        else:
            cmd_full(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

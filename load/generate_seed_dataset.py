#!/usr/bin/env python3
"""
Generate a small, self-contained, referentially-consistent Olist dataset from
scratch and write the 9 canonical CSVs into data/raw/ (or $OLIST_DATA_DIR/raw).

The real Olist CSVs (~120 MB) are gitignored, so CI has no data. This produces
a tiny stand-in — same 9 tables, same shapes, internally consistent — so the
whole pipeline (load --full -> dbt build --full-refresh -> test) can run in CI
with no external data. It also seeds a base that generate_fake_batch.py can then
extend with drift batches to exercise the incremental path.

    python load/generate_seed_dataset.py --seed 42

It reuses build_batch() from generate_fake_batch.py for the transactional tables
(one source of truth for that logic) and adds the dimension tables — products,
category translation, sellers and geolocation — with zips that line up so the
geo joins downstream actually resolve.
"""
import os
import csv
import random
import argparse
from datetime import datetime

from generate_fake_batch import build_batch, new_id, CITIES, COLS, RAW_DIR

# 12 real Olist categories that all have an English translation.
CATEGORIES = {
    "cama_mesa_banho":         "bed_bath_table",
    "beleza_saude":            "health_beauty",
    "esporte_lazer":           "sports_leisure",
    "moveis_decoracao":        "furniture_decor",
    "informatica_acessorios":  "computers_accessories",
    "utilidades_domesticas":   "housewares",
    "relogios_presentes":      "watches_gifts",
    "telefonia":               "telephony",
    "automotivo":              "auto",
    "brinquedos":              "toys",
    "cool_stuff":              "cool_stuff",
    "perfumaria":              "perfumery",
}

# Canonical filename per raw table (what load_raw.py's --full expects in data/raw/).
CANONICAL = {
    "orders":                       "olist_orders_dataset.csv",
    "order_items":                  "olist_order_items_dataset.csv",
    "order_payments":               "olist_order_payments_dataset.csv",
    "order_reviews":                "olist_order_reviews_dataset.csv",
    "customers":                    "olist_customers_dataset.csv",
    "sellers":                      "olist_sellers_dataset.csv",
    "products":                     "olist_products_dataset.csv",
    "product_category_translation": "product_category_name_translation.csv",
    "geolocation":                  "olist_geolocation_dataset.csv",
}

# Column orders for the dimension tables — must match sql/ddl/01_raw_schema.sql
# (the loader COPYs positionally).
DIM_COLS = {
    "products": ["product_id", "product_category_name", "product_name_lenght",
                 "product_description_lenght", "product_photos_qty", "product_weight_g",
                 "product_length_cm", "product_height_cm", "product_width_cm"],
    "product_category_translation": ["product_category_name", "product_category_name_english"],
    "sellers": ["seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"],
    "geolocation": ["geolocation_zip_code_prefix", "geolocation_lat", "geolocation_lng",
                    "geolocation_city", "geolocation_state"],
}


def write_raw(table, fieldnames, rows):
    os.makedirs(RAW_DIR, exist_ok=True)
    path = os.path.join(RAW_DIR, CANONICAL[table])
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"  {CANONICAL[table]:<40} {len(rows):>6} rows")


def build_geo_pool(n_zips):
    """A pool of zips, each with a Brazil-bbox lat/lng and a city/state.
    Returns (zip_list, geolocation_rows)."""
    zips, geo_rows = [], []
    seen = set()
    while len(zips) < n_zips:
        zip_prefix = str(random.randint(1000, 99999))
        if zip_prefix in seen:
            continue
        seen.add(zip_prefix)
        zips.append(zip_prefix)
        city, state = random.choice(CITIES)
        geo_rows.append({
            "geolocation_zip_code_prefix": zip_prefix,
            "geolocation_lat": round(random.uniform(-33.0, 5.0), 6),    # inside bbox
            "geolocation_lng": round(random.uniform(-73.0, -34.0), 6),  # inside bbox
            "geolocation_city": city,
            "geolocation_state": state,
        })
    return zips, geo_rows


def build_products(n_products):
    rows = []
    cats = list(CATEGORIES)
    for _ in range(n_products):
        rows.append({
            "product_id": new_id(),
            "product_category_name": random.choice(cats),
            "product_name_lenght": random.randint(20, 60),
            "product_description_lenght": random.randint(100, 3000),
            "product_photos_qty": random.randint(1, 6),
            "product_weight_g": random.randint(100, 30000),
            "product_length_cm": random.randint(5, 100),
            "product_height_cm": random.randint(2, 100),
            "product_width_cm": random.randint(5, 100),
        })
    return rows


def build_sellers(n_sellers, zip_pool):
    rows = []
    for _ in range(n_sellers):
        city, state = random.choice(CITIES)
        rows.append({
            "seller_id": new_id(),
            "seller_zip_code_prefix": random.choice(zip_pool),
            "seller_city": city,
            "seller_state": state,
        })
    return rows


def main():
    p = argparse.ArgumentParser(description="Generate a tiny full Olist dataset into data/raw/.")
    p.add_argument("--orders", type=int, default=500, help="number of orders")
    p.add_argument("--products", type=int, default=40, help="number of products")
    p.add_argument("--sellers", type=int, default=25, help="number of sellers")
    p.add_argument("--zips", type=int, default=60, help="number of geolocation zips")
    p.add_argument("--start", default="2018-01-01", help="earliest purchase date")
    p.add_argument("--end", default="2018-12-31", help="latest purchase date")
    p.add_argument("--seed", type=int, default=42, help="RNG seed for reproducibility")
    args = p.parse_args()

    random.seed(args.seed)
    start = datetime.strptime(args.start, "%Y-%m-%d")
    end = datetime.strptime(args.end, "%Y-%m-%d")

    print(f"Generating synthetic seed dataset → {RAW_DIR}")

    # dimensions first (transactions reference them)
    zip_pool, geo_rows = build_geo_pool(args.zips)
    products = build_products(args.products)
    sellers = build_sellers(args.sellers, zip_pool)
    translation = [{"product_category_name": pt, "product_category_name_english": en}
                   for pt, en in CATEGORIES.items()]

    write_raw("geolocation", DIM_COLS["geolocation"], geo_rows)
    write_raw("products", DIM_COLS["products"], products)
    write_raw("product_category_translation", DIM_COLS["product_category_translation"], translation)
    write_raw("sellers", DIM_COLS["sellers"], sellers)

    # transactions (reuse the batch builder; no drift in the base dataset)
    product_ids = [r["product_id"] for r in products]
    seller_ids = [r["seller_id"] for r in sellers]
    rows = build_batch(args.orders, start, end, product_ids, seller_ids,
                       new_status=False, new_payment_type=False, zip_pool=zip_pool)

    for table in ("orders", "customers", "order_items", "order_payments", "order_reviews"):
        write_raw(table, COLS[table], rows[table])

    print("Seed dataset ready.")


if __name__ == "__main__":
    main()

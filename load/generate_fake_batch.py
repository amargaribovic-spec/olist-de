#!/usr/bin/env python3
"""
Generate a fake Olist-shaped batch of NEW data into data/incoming/.

Simulates future data arriving from Olist. Referentially consistent: new orders
reference EXISTING products and sellers (read from data/raw/), while new
customers / orders / items / payments / reviews are generated together. The
loader picks these up in --append mode.

Examples
--------
  # 500 new orders spread across Q1 2019
  python load/generate_fake_batch.py --orders 500 --start 2019-01-01 --end 2019-03-31 --label 2019q1

  # a small batch that also exercises drift + updates (for CI / resilience tests)
  python load/generate_fake_batch.py --orders 50 --new-status --new-payment-type --update-existing --seed 42

Drift options (prove the pipeline tolerates valid new data instead of breaking):
  --new-status        some orders get a brand-new status ('returned')
  --new-payment-type  some payments get a brand-new type ('pix')
  --update-existing   re-emit a few EXISTING orders with a changed status
                      (tests the incremental merge / upsert path)

Output: one CSV per table in data/incoming/, named "<table>__<label>.csv" so the
loader knows the target table. Column order matches the raw CSVs (positional load).
"""
import os
import csv
import uuid
import random
import argparse
from datetime import datetime, timedelta

HERE = os.path.dirname(__file__)
RAW_DIR = os.path.join(HERE, "..", "data", "raw")
OUT_DIR = os.path.join(HERE, "..", "data", "incoming")

FMT = "%Y-%m-%d %H:%M:%S"

# Column orders — must match sql/ddl/01_raw_schema.sql (loader loads positionally).
COLS = {
    "customers": ["customer_id", "customer_unique_id", "customer_zip_code_prefix",
                  "customer_city", "customer_state"],
    "orders": ["order_id", "customer_id", "order_status", "order_purchase_timestamp",
               "order_approved_at", "order_delivered_carrier_date",
               "order_delivered_customer_date", "order_estimated_delivery_date"],
    "order_items": ["order_id", "order_item_id", "product_id", "seller_id",
                    "shipping_limit_date", "price", "freight_value"],
    "order_payments": ["order_id", "payment_sequential", "payment_type",
                       "payment_installments", "payment_value"],
    "order_reviews": ["review_id", "order_id", "review_score", "review_comment_title",
                      "review_comment_message", "review_creation_date",
                      "review_answer_timestamp"],
}

PAYMENT_TYPES = ["credit_card", "boleto", "voucher", "debit_card"]
CITIES = [("sao paulo", "SP"), ("rio de janeiro", "RJ"), ("belo horizonte", "MG"),
          ("curitiba", "PR"), ("porto alegre", "RS"), ("salvador", "BA"),
          ("recife", "PE"), ("fortaleza", "CE"), ("brasilia", "DF"), ("manaus", "AM")]


def new_id():
    return uuid.uuid4().hex  # 32-char hex, same shape as Olist ids


def read_column(csv_name, column, limit=None):
    """Read one column from a raw CSV (to reference real products/sellers/orders)."""
    path = os.path.join(RAW_DIR, csv_name)
    vals = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            vals.append(row[column])
            if limit and len(vals) >= limit:
                break
    return vals


def read_rows(csv_name, columns, limit=None):
    """Read several columns from a raw CSV as tuples (to keep FK pairs together)."""
    path = os.path.join(RAW_DIR, csv_name)
    out = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            out.append(tuple(row[c] for c in columns))
            if limit and len(out) >= limit:
                break
    return out


def rand_ts(start, end):
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


def build_batch(n_orders, start, end, product_ids, seller_ids,
                new_status, new_payment_type):
    rows = {t: [] for t in COLS}

    for _ in range(n_orders):
        order_id = new_id()
        customer_id = new_id()
        city, state = random.choice(CITIES)
        zip_prefix = str(random.randint(1000, 99999))

        # customer (one per order, Olist-style)
        rows["customers"].append({
            "customer_id": customer_id,
            "customer_unique_id": new_id(),
            "customer_zip_code_prefix": zip_prefix,
            "customer_city": city,
            "customer_state": state,
        })

        # order + a consistent delivery timeline
        purchase = rand_ts(start, end)
        approved = purchase + timedelta(hours=random.randint(1, 24))
        carrier = approved + timedelta(days=random.randint(1, 3))
        delivered = carrier + timedelta(days=random.randint(2, 12))
        estimated = purchase + timedelta(days=random.randint(10, 30))

        roll = random.random()
        if new_status and roll < 0.05:
            status = "returned"                       # brand-new value (drift)
        elif roll < 0.90:
            status = "delivered"
        elif roll < 0.96:
            status = "shipped"
        else:
            status = "canceled"

        def ts(dt):
            return dt.strftime(FMT)

        rows["orders"].append({
            "order_id": order_id,
            "customer_id": customer_id,
            "order_status": status,
            "order_purchase_timestamp": ts(purchase),
            "order_approved_at": ts(approved),
            "order_delivered_carrier_date": ts(carrier) if status in ("delivered", "returned") else "",
            "order_delivered_customer_date": ts(delivered) if status in ("delivered", "returned") else "",
            "order_estimated_delivery_date": ts(estimated),
        })

        # 1–3 items referencing REAL products / sellers
        for item_id in range(1, random.randint(1, 3) + 1):
            price = round(random.uniform(10, 500), 2)
            rows["order_items"].append({
                "order_id": order_id,
                "order_item_id": item_id,
                "product_id": random.choice(product_ids),
                "seller_id": random.choice(seller_ids),
                "shipping_limit_date": ts(carrier),
                "price": price,
                "freight_value": round(random.uniform(5, 60), 2),
            })

        # payment
        ptype = random.choice(PAYMENT_TYPES)
        if new_payment_type and random.random() < 0.05:
            ptype = "pix"                             # brand-new value (drift)
        rows["order_payments"].append({
            "order_id": order_id,
            "payment_sequential": 1,
            "payment_type": ptype,
            "payment_installments": random.randint(1, 10),
            "payment_value": round(random.uniform(20, 800), 2),
        })

        # review (only for orders that reached the customer)
        if status in ("delivered", "returned"):
            created = delivered + timedelta(days=random.randint(0, 3))
            answered = created + timedelta(hours=random.randint(1, 72))
            rows["order_reviews"].append({
                "review_id": new_id(),
                "order_id": order_id,
                "review_score": random.randint(1, 5),
                "review_comment_title": "",
                "review_comment_message": "",
                "review_creation_date": ts(created),
                "review_answer_timestamp": ts(answered),
            })

    return rows


def add_updated_orders(rows, n, start, end):
    """Re-emit a few EXISTING orders with a changed status → tests incremental merge.
    Keeps each order's real customer_id so referential integrity holds."""
    existing = read_rows("olist_orders_dataset.csv", ["order_id", "customer_id"], limit=5000)
    picks = random.sample(existing, min(n, len(existing)))
    for order_id, customer_id in picks:
        purchase = rand_ts(start, end)
        rows["orders"].append({
            "order_id": order_id,                     # SAME id as an existing order
            "customer_id": customer_id,               # ...and its real customer
            "order_status": "canceled",               # a status transition
            "order_purchase_timestamp": purchase.strftime(FMT),
            "order_approved_at": "",
            "order_delivered_carrier_date": "",
            "order_delivered_customer_date": "",
            "order_estimated_delivery_date": (purchase + timedelta(days=15)).strftime(FMT),
        })
    return picks


def write_csv(table, rows, label):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{table}__{label}.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLS[table])
        writer.writeheader()
        writer.writerows(rows)
    return path, len(rows)


def main():
    p = argparse.ArgumentParser(description="Generate a fake Olist batch into data/incoming/.")
    p.add_argument("--orders", type=int, default=500, help="number of new orders")
    p.add_argument("--start", default="2019-01-01", help="earliest purchase date (YYYY-MM-DD)")
    p.add_argument("--end", default="2019-03-31", help="latest purchase date (YYYY-MM-DD)")
    p.add_argument("--label", default=None, help="batch label used in filenames")
    p.add_argument("--seed", type=int, default=None, help="RNG seed for reproducible batches")
    p.add_argument("--new-status", action="store_true", help="inject a new order_status ('returned')")
    p.add_argument("--new-payment-type", action="store_true", help="inject a new payment_type ('pix')")
    p.add_argument("--update-existing", type=int, nargs="?", const=3, default=0,
                   help="re-emit N existing orders with a changed status (default 3)")
    args = p.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    start = datetime.strptime(args.start, "%Y-%m-%d")
    end = datetime.strptime(args.end, "%Y-%m-%d")
    label = args.label or f"{args.start}_{args.end}"

    product_ids = read_column("olist_products_dataset.csv", "product_id")
    seller_ids = read_column("olist_sellers_dataset.csv", "seller_id")

    rows = build_batch(args.orders, start, end, product_ids, seller_ids,
                       args.new_status, args.new_payment_type)

    updated = []
    if args.update_existing:
        updated = add_updated_orders(rows, args.update_existing, start, end)

    print(f"Generating batch '{label}' → {OUT_DIR}")
    for table in COLS:
        path, n = write_csv(table, rows[table], label)
        print(f"  {os.path.basename(path):<40} {n:>6} rows")
    if args.new_status:
        print("  (drift) some orders use new status 'returned'")
    if args.new_payment_type:
        print("  (drift) some payments use new type 'pix'")
    if updated:
        print(f"  (merge) re-emitted {len(updated)} existing orders as 'canceled'")


if __name__ == "__main__":
    main()

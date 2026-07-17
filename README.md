# olist-de — Data Engineering

Data Engineering phase of the FEP project. It takes the same Olist e-commerce
CSVs used in the analysis phase and builds a proper **ELT pipeline** into
PostgreSQL, ready for **dbt** to transform.

## Pipeline

```
CSV files  ──(this repo: Extract + Load)──►  raw schema in Postgres  ──(dbt, later: Transform)──►  staging → marts
```

- **Now (this repo):** land the 9 CSVs into a `raw` schema, exactly as-is
  (all TEXT, no constraints).
- **Later (dbt, ~15 days):** cast types, clean, test, and model into a star
  schema (`stg_` → `dim_` / `fct_`).

The rules we follow are in [`skills.md`](skills.md).

## Structure

```
olist-de/
├── README.md
├── skills.md                  # working rules & conventional commits
├── .gitignore
├── .env.example               # connection template (copy to .env)
├── requirements.txt           # python deps for the loader
├── data/
│   └── raw/                   # put the 9 Olist CSVs here (gitignored)
├── sql/
│   └── ddl/
│       └── 01_raw_schema.sql  # raw schema + 9 tables (all TEXT)
├── load/
│   ├── config.py              # reads .env -> DB connection
│   └── load_raw.py            # idempotent CSV -> raw loader
└── dbt/                       # placeholder — dbt project goes here later
```

## Database — decide later, one file changes

The connection lives in `.env`, so the database choice (Docker / local /
Supabase) is a **config change only** — no code changes. See `.env.example`.

## Setup

```bash
# 1. start Postgres in Docker (its own isolated instance)
docker compose up -d          # Postgres now running at localhost:5432

# 2. python environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. connection (defaults already match docker-compose.yml)
cp .env.example .env

# 4. put the 9 CSVs into data/raw/

# 5. create the raw schema + load everything (idempotent, re-runnable)
python load/load_raw.py --create

# later reloads (schema already exists)
python load/load_raw.py
```

Handy Docker commands:
```bash
docker compose up -d      # start (background)
docker compose down       # stop, keep the data
docker compose down -v    # stop and DELETE the data (fresh start)
docker exec -it olist_postgres psql -U olist -d olist   # open a SQL shell inside the container
```

## Data source

Brazilian E-Commerce Public Dataset by Olist (Kaggle) — the same 9 CSVs as the
analysis phase: orders, order_items, order_payments, order_reviews, customers,
sellers, products, product_category_name_translation, geolocation.

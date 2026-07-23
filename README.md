# olist-de — Data Engineering

Data Engineering phase of the FEP project. It takes the same Olist e-commerce
CSVs used in the analysis phase and builds a proper **ELT pipeline** into
PostgreSQL, ready for **dbt** to transform.

## Pipeline

```
CSV files  ──(this repo: Extract + Load)──►  raw schema in Postgres  ──(dbt, later: Transform)──►  staging → marts
```

- **Load (this repo):** land the 9 CSVs into a `raw` schema, exactly as-is
  (all TEXT, no constraints).
- **Transform (dbt, in `dbt/`):** sources for all 9 raw tables, a typed staging
  layer (`stg_`), and marts. See [`dbt/README.md`](dbt/README.md) for dbt usage.

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
└── dbt/                       # dbt project — sources, staging, marts (see dbt/README.md)
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

## Running with Docker (containerized workflow)

The whole pipeline runs in containers — a fresh clone needs only Docker, no local
Python. The `loader` and `dbt` services sit behind the `tools` compose profile,
so `up` starts only Postgres; run the others on demand.

```bash
# 1. start Postgres
docker compose up -d

# 2. create the raw schema + load the 9 CSVs (one-off; --create builds the schema)
docker compose run --rm loader python load/load_raw.py --create
#    (reload only, schema already exists)
docker compose run --rm loader

# 3. install dbt packages, then build the models
docker compose run --rm dbt dbt deps
docker compose run --rm dbt dbt build

# any other dbt command works the same way
docker compose run --rm dbt dbt run
docker compose run --rm dbt dbt test
docker compose run --rm dbt dbt docs generate
```

Connection is wired via env vars: compose sets `DB_HOST=postgres` for the
containers, while the same `dbt/profiles.yml` falls back to `localhost:5544` when
you run dbt from the local venv — so both workflows stay in sync. The local venv
is kept only for editor integration and fast formatting; **Docker is the source
of truth for running the pipeline.**

## Data source

Brazilian E-Commerce Public Dataset by Olist (Kaggle) — the same 9 CSVs as the
analysis phase: orders, order_items, order_payments, order_reviews, customers,
sellers, products, product_category_name_translation, geolocation.

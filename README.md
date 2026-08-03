# olist-de — Data Engineering

Data Engineering phase of the FEP project. It takes the same Olist e-commerce
CSVs used in the analysis phase and builds a **continuous ELT pipeline** into
PostgreSQL, transformed with **dbt** — designed so that new Olist data can keep
arriving over time without breaking or rebuilding from scratch.

## Pipeline

```
CSV batches ──(Extract + Load)──►  raw schema (append-only)  ──(dbt Transform)──►  staging → intermediate → marts
```

- **Load:** land CSVs into an append-only `raw` schema. Every row is stamped with
  `_loaded_at`; every file is recorded in `raw._load_ledger` (by sha256) so the
  same file is never loaded twice.
- **Transform (dbt, in `dbt/`):** sources for all 9 raw tables → a typed `stg_`
  layer that **dedups each key to its latest row** → an intermediate layer
  (reusable joins/logic) → marts, with a test suite across every layer. The
  per-order marts are **incremental** (merge on `order_id`); the aggregates are
  tables. See [`dbt/README.md`](dbt/README.md) for dbt usage.

The rules we follow are in [`skills.md`](skills.md).

## Two ways to run it

The pipeline is built for data that keeps arriving, so there are two modes:

```bash
./run.sh fresh    # WIPE everything and rebuild as if running for the first time
                  #   down -v → up → load --full → dbt build --full-refresh
./run.sh build    # CONTINUE: load only NEW batches, then an incremental dbt build
                  #   up → load --append → dbt build
```

Both go through `run.sh`, which orchestrates Docker. Other modes:

| command | what it does |
|---|---|
| `./run.sh` | full run: up → load (full if empty, else new batches) → build |
| `./run.sh up` | start Postgres and wait until it accepts connections |
| `./run.sh load` | load only new batches from `data/incoming/` (append) |
| `./run.sh load-full` | clean full load (truncate + canonical CSVs + replay batches) |
| `./run.sh generate ..` | generate a fake Olist batch into `data/incoming/` (see below) |
| `./run.sh build-only` | `dbt deps` + `dbt build`, no loading |
| `./run.sh refresh` | `dbt deps` + `dbt build --full-refresh` |
| `./run.sh down` | stop containers, keep the data |

## Continuous ingestion

New data is modelled as **batches**, not a one-off load:

- `raw` is **append-only** — batches are added, never overwritten. `_loaded_at`
  and `raw._load_ledger` (sha256 per file) make `--append` safe to re-run.
- **Staging dedups to the latest row per key** (`row_number() … order by
  _loaded_at desc`), so a re-emitted order (e.g. a status change) resolves to its
  newest version. Uniqueness is enforced in staging, after the dedup — not on the
  append-only raw layer.
- The five per-order marts are **incremental** (`merge` on `order_id`, filtered by
  `_loaded_at > ` the model's high-water mark via the `incremental_watermark`
  macro). A `--full-refresh` rebuilds them from scratch; a plain `build` merges
  only what changed.
- **Drift does not break the pipeline.** New-but-valid values are surfaced as
  `warn`, not `error`: a brand-new `order_status` or `payment_type` warns instead
  of failing, and an unanswered review (`review_answer_timestamp` null) warns.
  Percentage reconciliation tolerances scale with row count, so they stay correct
  as the data grows.

### Simulating new data

`load/generate_fake_batch.py` produces referentially-consistent Olist-shaped
batches — new customers/orders/items/payments/reviews that reference existing
products and sellers. It can also inject drift, to prove the pipeline tolerates it:

```bash
# 500 new orders across Q1 2019
./run.sh generate --orders 500 --start 2019-01-01 --end 2019-03-31 --label 2019q1

# a small batch exercising drift + updates (new status, new payment type, re-emits)
./run.sh generate --orders 50 --new-status --new-payment-type --update-existing --seed 42

# then land + build it
./run.sh build
```

## Continuous integration

[`.github/workflows/lint.yml`](.github/workflows/lint.yml) runs **`sqlfluff lint`
on every pull request into `main`**. It spins up an empty Postgres (the dbt
templater compiles the project but reads no data — no CSVs needed in CI),
installs the pinned dbt + sqlfluff, runs `dbt deps`, then lints `models/`.

To **block merges until lint passes**, mark the `sqlfluff lint (dbt models)` check
as **Required** in the branch-protection rule for `main`
(Settings → Branches → Branch protection rules).

## Structure

```
olist-de/
├── README.md
├── skills.md                       # working rules & conventional commits
├── .github/workflows/lint.yml      # CI: sqlfluff lint on PRs
├── .gitignore
├── .env.example                    # connection template (copy to .env)
├── requirements.txt                # python deps for the loader
├── docker-compose.yml              # postgres + loader + dbt services
├── run.sh                          # pipeline orchestration (fresh / build / …)
├── data/
│   ├── raw/                        # the 9 canonical Olist CSVs (gitignored)
│   ├── incoming/                   # new batches waiting to be loaded
│   └── processed/                  # batches already loaded
├── sql/
│   └── ddl/
│       └── 01_raw_schema.sql       # raw schema, 9 tables, _loaded_at + load ledger
├── load/
│   ├── config.py                   # reads .env -> DB connection
│   ├── load_raw.py                 # append-only CSV -> raw loader (--full / --append)
│   └── generate_fake_batch.py      # fake batch generator (with drift scenarios)
└── dbt/                            # dbt project — sources, staging, intermediate,
                                    #   marts, tests, macros (see dbt/README.md)
```

## Setup

```bash
# 1. start Postgres in Docker (exposed on localhost:5544)
docker compose up -d

# 2. python environment (for the loader / local dbt & sqlfluff)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. connection (defaults already match docker-compose.yml)
cp .env.example .env

# 4. put the 9 canonical Olist CSVs into data/raw/

# 5. first full build (wipe + load + build)
./run.sh fresh
```

Handy Docker commands:
```bash
docker compose up -d      # start (background)
docker compose down       # stop, keep the data
docker compose down -v    # stop and DELETE the data (fresh start)
docker exec -it olist_postgres psql -U olist -d olist   # SQL shell in the container
```

Connection is wired via env vars: compose sets `DB_HOST=postgres` for the
containers, while the same `dbt/profiles.yml` falls back to `localhost:5544` when
you run dbt from the local venv — so both workflows stay in sync. The local venv
is kept for editor integration and fast lint/format; **Docker is the source of
truth for running the pipeline.**

## Data source

Brazilian E-Commerce Public Dataset by Olist (Kaggle) — the 9 CSVs from the
analysis phase: orders, order_items, order_payments, order_reviews, customers,
sellers, products, product_category_name_translation, geolocation.

"""
olist_build — the continuous-ingestion pipeline as a scheduled Airflow DAG.

Runs the real pipeline as containerised tasks:

    load_raw --append  ->  dbt deps  ->  dbt build

dbt and the loader run from an isolated venv baked into the image
(/opt/pipeline-venv), so their dependencies never clash with Airflow's. The
warehouse is reached over the Docker network by service name (DB_HOST=postgres),
using the same env vars profiles.yml and load/config.py already read.

Why each step is safe for Airflow to retry (the reason this belongs in an
orchestrator at all):
  - load_raw --append is idempotent: raw._load_ledger (sha256 per file) means a
    re-run never double-loads a batch already seen.
  - staging dedups to the latest row per key, so replays never create duplicates.
  - the per-order marts MERGE on order_id above a watermark, so rebuilding a row
    already present is a no-op.
So a failed task can simply be retried with no manual cleanup and no data drift.

Note: `dbt build` already interleaves run + test per model, so there is
deliberately NO separate `dbt test` task.

To feed it data: drop a batch into data/incoming/ (e.g. `./run.sh generate ...`),
then trigger this DAG — load_raw picks it up. In production an upstream export /
object-storage would land files there instead.
"""
from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG

# BashOperator moved packages between Airflow 2 and 3 — import it either way.
try:
    from airflow.providers.standard.operators.bash import BashOperator  # Airflow 3
except ImportError:  # Airflow 2.x
    from airflow.operators.bash import BashOperator

# Repo dirs are mounted here (see airflow/docker-compose.yml); dbt + loader run
# from the isolated pipeline venv baked into the image.
OLIST_HOME = "/opt/airflow/olist"
DBT_DIR = f"{OLIST_HOME}/dbt"
PY = "/opt/pipeline-venv/bin/python"
DBT = "/opt/pipeline-venv/bin/dbt"

default_args = {
    "owner": "amar",
    "retries": 2,
    "retry_delay": timedelta(minutes=1),
}

with DAG(
    dag_id="olist_build",
    description="Append new Olist batches, then run an incremental dbt build + tests.",
    default_args=default_args,
    start_date=datetime(2026, 8, 1),  # fixed date in the past — never datetime.now()
    schedule="@daily",
    catchup=False,      # do NOT backfill one run per day since start_date
    max_active_runs=1,  # never let two loads race into append-only raw
    tags=["olist", "elt", "dbt"],
) as dag:

    load_raw = BashOperator(
        task_id="load_raw",
        cwd=OLIST_HOME,
        bash_command=f"{PY} load/load_raw.py --append",
    )

    # Cheap + idempotent; kept separate so a packages problem shows as its own
    # red node rather than failing the build.
    dbt_deps = BashOperator(
        task_id="dbt_deps",
        cwd=DBT_DIR,
        bash_command=f"{DBT} deps",
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        cwd=DBT_DIR,
        bash_command=f"{DBT} build",
    )

    load_raw >> dbt_deps >> dbt_build

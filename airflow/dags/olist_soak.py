"""
olist_soak — a self-feeding SOAK TEST of the pipeline (NOT the real pipeline).

Every 20 minutes it generates a fresh fake batch, then runs the normal
ingest + build — so you can leave it running for a couple of hours and watch the
pipeline handle a continuous stream of new data end to end:

    generate_batch  ->  load_raw --append  ->  dbt deps  ->  dbt build

Each run makes its own batch with a unique filename (--label {{ ts_nodash }}), so
batch files never collide and every run brings genuinely new orders.

A demo/soak DAG, separate from the real pipeline (`olist_build`). It's paused by
default — unpause it only when you want to run a soak test, and pause it after.
"""
from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG

try:
    from airflow.providers.standard.operators.bash import BashOperator  # Airflow 3
except ImportError:  # Airflow 2.x
    from airflow.operators.bash import BashOperator

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
    dag_id="olist_soak",
    description="SOAK TEST: generate a fake batch and run the pipeline every 20 min.",
    default_args=default_args,
    start_date=datetime(2026, 8, 1),
    schedule="*/20 * * * *",   # every 20 minutes
    catchup=False,
    max_active_runs=1,
    tags=["olist", "soak-test"],
) as dag:

    generate_batch = BashOperator(
        task_id="generate_batch",
        cwd=OLIST_HOME,
        # unique label per run -> batch files never collide; random data each run
        bash_command=(
            f"{PY} load/generate_fake_batch.py --orders 100 "
            "--label {{ ts_nodash }}"
        ),
    )

    load_raw = BashOperator(
        task_id="load_raw",
        cwd=OLIST_HOME,
        bash_command=f"{PY} load/load_raw.py --append",
    )

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

    generate_batch >> load_raw >> dbt_deps >> dbt_build

FROM python:3.11-slim

# git is needed by dbt (dependency check + git-based packages)
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# dbt + Postgres adapter + sqlfluff (lint & format), pinned to match the local venv
RUN pip install --no-cache-dir \
    dbt-postgres==1.9.1 \
    sqlfluff==4.1.0 \
    sqlfluff-templater-dbt==4.1.0

WORKDIR /dbt

# profiles.yml lives inside the project and resolves the connection from env vars
ENV DBT_PROFILES_DIR=/dbt

# The project is bind-mounted by docker-compose, so nothing is COPYed in.
# Packages (codegen) are installed into the mounted volume via `dbt deps`.
CMD ["dbt", "--version"]

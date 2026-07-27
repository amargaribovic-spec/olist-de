#!/usr/bin/env bash
#
# run.sh — orchestrate the olist-de pipeline via Docker.
#
#   ./run.sh            all: up -> load (only if needed) -> build
#   ./run.sh up         start postgres and wait until it accepts connections
#   ./run.sh load       load raw (skips if already loaded; 'load --force' reloads)
#   ./run.sh build      dbt deps + dbt build
#   ./run.sh fresh      WIPE the db volume, then up + load + build (recovery)
#   ./run.sh down       stop containers, keep the data
#
set -euo pipefail
cd "$(dirname "$0")"                      # always run from the repo root

COMPOSE="docker compose"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

wait_for_pg() {
    log "waiting for postgres to accept connections..."
    until docker exec olist_postgres pg_isready -U olist -d olist >/dev/null 2>&1; do
        sleep 1
    done
    echo "postgres is ready."
}

raw_loaded() {
    # succeeds (exit 0) only if raw.orders exists AND has at least one row
    local n
    n="$(docker exec olist_postgres psql -U olist -d olist -tAc \
        'SELECT count(*) FROM raw.orders' 2>/dev/null || echo '')"
    [[ -n "$n" && "$n" -gt 0 ]]
}

cmd_up() {
    log "starting postgres"
    $COMPOSE up -d
    wait_for_pg
}

cmd_load() {
    if raw_loaded && [[ "${1:-}" != "--force" ]]; then
        log "raw already loaded (raw.orders has rows) — skipping. Use './run.sh load --force' to reload."
    else
        log "loading raw CSVs (create schema + load)"
        $COMPOSE run --rm loader python load/load_raw.py --create
    fi
}

cmd_build() {
    log "installing dbt packages"
    $COMPOSE run --rm dbt dbt deps
    log "building dbt models"
    $COMPOSE run --rm dbt dbt build
}

cmd_all() {
    cmd_up
    cmd_load
    cmd_build
    log "pipeline complete ✅"
}

cmd_fresh() {
    log "WIPING the database volume and rebuilding from scratch"
    $COMPOSE down -v
    cmd_up
    $COMPOSE run --rm loader python load/load_raw.py --create   # always load on a fresh volume
    cmd_build
    log "fresh rebuild complete ✅"
}

cmd_down() {
    log "stopping containers (data kept in the volume)"
    $COMPOSE down
}

case "${1:-all}" in
    up)         cmd_up ;;
    load)       shift || true; cmd_load "${1:-}" ;;
    build|dbt)  cmd_build ;;
    all)        cmd_all ;;
    fresh)      cmd_fresh ;;
    down)       cmd_down ;;
    *)
        echo "usage: ./run.sh [all|up|load [--force]|build|fresh|down]"
        exit 1
        ;;
esac

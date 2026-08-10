#!/usr/bin/env bash
# run.sh — orchestrate the olist-de pipeline via Docker.
#
# Two ingestion modes, built for continuous data arriving from Olist:
#
#   ./run.sh fresh        WIPE everything and rebuild from the ORIGINAL 9 CSVs only
#                         (down -v -> up -> canonical load -> dbt build --full-refresh).
#                         Batches are NOT replayed — add them on demand with `load`.
#   ./run.sh build        continue: load only NEW batches, then incremental dbt build
#
#   ./run.sh              all: up -> load (full if empty, else new batches) -> build
#   ./run.sh up           start postgres and wait until it accepts connections
#   ./run.sh load         load only new batches from data/incoming/ (append)
#   ./run.sh load-full    clean full load (truncate + canonical + replay batches)
#   ./run.sh generate ..  generate a fake Olist batch into data/incoming/
#                         e.g. ./run.sh generate --orders 500 --new-status --seed 42
#   ./run.sh build-only   dbt deps + dbt build (no loading)
#   ./run.sh refresh      dbt deps + dbt build --full-refresh (rebuild incrementals)
#   ./run.sh clean-batches  delete batch files in data/incoming + data/processed
#                         (regenerable fake data). Pair with `fresh` for a pristine reset.
#   ./run.sh down         stop containers, keep the data
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

cmd_load() {        # incremental: append only new batches
    log "loading new batches (append)"
    $COMPOSE run --rm loader python load/load_raw.py --append
}

cmd_load_full() {   # clean full load → original 9 CSVs only
    log "full load (truncate + canonical CSVs only; batches not replayed)"
    $COMPOSE run --rm loader python load/load_raw.py --full
}

cmd_clean_batches() {   # delete batch files (incoming + processed) — they're regenerable fake data
    local removed=0
    for dir in data/incoming data/processed; do
        for f in "$dir"/*.csv; do
            [ -e "$f" ] || continue          # no matches -> skip the literal glob
            rm -f "$f"
            removed=$((removed + 1))
        done
    done
    log "deleted $removed batch file(s) from data/incoming + data/processed"
    echo "raw tables still hold their rows — run './run.sh fresh' to rebuild from the 9 canonical CSVs only."
}

cmd_generate() {    # generate a fake batch into data/incoming/
    log "generating fake Olist batch"
    $COMPOSE run --rm loader python load/generate_fake_batch.py "$@"
}

cmd_build() {       # dbt deps + build (optionally --full-refresh)
    log "installing dbt packages"
    $COMPOSE run --rm dbt dbt deps
    log "building dbt models${1:+ (full refresh)}"
    $COMPOSE run --rm dbt dbt build ${1:-}
}

cmd_all() {
    cmd_up
    if raw_loaded; then cmd_load; else cmd_load_full; fi
    cmd_build
    log "pipeline complete ✅"
}

cmd_build_incremental() {   # the mentor's "build": continue with new info
    cmd_up
    cmd_load
    cmd_build
    log "incremental build complete ✅"
}

cmd_fresh() {               # the mentor's "full refresh": like running the first time
    log "WIPING the database volume → clean first-run rebuild"
    $COMPOSE down -v
    cmd_up
    cmd_load_full
    cmd_build "--full-refresh"
    log "fresh rebuild complete ✅"
}

cmd_down() {
    log "stopping containers (data kept in the volume)"
    $COMPOSE down
}

case "${1:-all}" in
    up)                 cmd_up ;;
    load)               cmd_load ;;
    load-full)          cmd_load_full ;;
    generate)           shift || true; cmd_generate "$@" ;;
    build)              cmd_build_incremental ;;
    build-only|dbt)     cmd_build ;;
    refresh)            cmd_up; cmd_build "--full-refresh" ;;
    clean-batches)      cmd_clean_batches ;;
    all)                cmd_all ;;
    fresh|full-refresh) cmd_fresh ;;
    down)               cmd_down ;;
    *)
        echo "usage: ./run.sh [all|fresh|build|up|load|load-full|generate ..|build-only|refresh|clean-batches|down]"
        exit 1
        ;;
esac

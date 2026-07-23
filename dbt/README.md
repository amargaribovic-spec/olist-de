# Olist dbt project

Transforms the raw Olist e-commerce data (loaded into the `raw` schema of the
local Postgres) into clean, typed, analytics-ready models.

- **Source data:** schema `raw` (9 tables, loaded from CSV — see `../load/`)
- **dbt output:** schema `dbt_amar`
- **Layers:** `models/staging/` (1:1 cleaned sources) → `models/intermediate/`
  (reusable joins/logic) → `models/marts/` (business-ready outputs)

## Setup

Run everything from this `dbt/` folder with the project venv active:

```bash
cd path/to/olist-de/dbt
source ../venv/bin/activate     # prompt shows (venv)
dbt deps                        # install packages (codegen, dbt_utils)
dbt debug                       # verify the Postgres connection is green
```

Connection lives in `~/.dbt/profiles.yml` (profile `olist`): host `localhost`,
port `5544`, db/user/pass all `olist`.

## Everyday commands

```bash
dbt run                       # build all models
dbt run --select stg_orders+  # build one model + everything downstream of it
dbt build                     # run models AND their tests together
dbt test                      # run tests only
```

## Linting & formatting with sqlfluff

`sqlfluff` is our single tool for both linting and formatting SQL (config in
`.sqlfluff`: Postgres dialect + dbt templater). It checks rules (naming, layout,
references) *and* auto-fixes style. Because it uses the dbt templater, it lints
the real compiled SQL behind `ref()` / `source()`.

```bash
sqlfluff lint models/   # report rule violations (this is the CI gate)
sqlfluff fix models/    # auto-fix what it can, in place
```

Run `fix` then `lint` before committing so the diff stays clean and CI-ready.

## Docs & lineage graph

Generate the docs site, then serve it to explore the lineage (DAG):

```bash
dbt docs generate       # build the docs from the project (re-run after changes)
dbt docs serve          # start the site at http://localhost:8080
```

Open <http://localhost:8080>, then click the blue circle (bottom-right) to see
the lineage graph: green nodes are sources, blue nodes are models. Press
`Ctrl+C` in the terminal to stop the server.

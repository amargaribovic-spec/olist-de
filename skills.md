# olist-de — Working Rules & Conventions

Rules to follow for this data-engineering phase. The first group is carried over
from the analysis phase (olist-analytics); the second is data-engineering
specific; the last is git/commit hygiene.

---

## 1. Carried over from the analysis phase

1. **Raw data is sacred.** Never modify the source CSVs. All shaping happens in
   the database / dbt, never in the original files.
2. **Reproducible & idempotent.** Every script must be safe to re-run and give
   the same result (the loader TRUNCATEs then reloads — no duplicates, no drift).
3. **Consistency / code reuse.** Solve the same problem the same way everywhere.
   Don't invent a second pattern for something already done once.
4. **One job per file/step.** Reading, DDL, loading, and (later) transforming are
   separate, each doing one clear thing.
5. **Document the WHY, not just the what.** Comments and docs explain the reason
   for a decision, so anyone (including future you) can defend it.

## 2. Data-engineering rules

6. **Layered ELT: raw → staging → intermediate → marts.**
   - `raw`   = land the CSVs exactly as-is.
   - `stg_`  = one model per source table: cast types, rename, light clean.
     Stays 1:1 with the source (all columns, no joins, no aggregations).
   - `int_`  = reusable middle steps: joins/aggregations shared by more than one
     mart, or logic extracted to keep a mart readable. Only create an
     intermediate model when the logic is actually reused — don't add empty layers.
   - `dim_` / `fct_` (marts) = the modelled star schema, business-ready outputs.
   Never clean in the raw layer.
7. **Raw layer is permissive.** Every raw column is TEXT, with no PK/FK/CHECK.
   Goal: a bad value can never fail the load. Typing and validation come later.
8. **Constraints become dbt tests, not DB constraints.**
   - primary key  → `unique` + `not_null`
   - foreign key  → `relationships`
   - value rule   → `accepted_values`
   - composite key → `dbt_utils.unique_combination_of_columns`
9. **Naming convention.** `raw.<table>`, then `stg_<entity>`, `int_<step>`,
   `dim_<entity>`, `fct_<event>`.
10. **Tables connect via JOINs in models**, on the shared key columns — the ERD
    is the join map. `ref()` builds the model dependency graph in dbt.
11. **Secrets & config live in `.env`, never in code, never in git.** The DB
    choice (Docker / local / Supabase) changes only `.env`.
12. **Carry the known data-quality issues forward as the test spec** (from the
    analysis flags):
    - `review_id` is NOT unique (collisions) and `order_id` repeats in reviews
      → reviews need a surrogate key / dedup to most-recent-per-order.
    - `geolocation` has ~53 rows per zip → aggregate to one row per zip.
    - masked nulls (text like "N/A", "-") exist → treat as null in staging.
    - impossible timestamp orders and pre-delivery reviews exist → handle/flag.
    - `order_items` PK = (order_id, order_item_id); `order_payments` PK =
      (order_id, payment_sequential) → composite-key tests.

13. **Source column naming — zip prefix.** In the source CSVs the zip column in
    `customers` and `sellers` is named **`geolocation_zip_code_prefix`** (the same
    name as in the `geolocation` table), not `customer_zip_code_prefix` /
    `seller_zip_code_prefix`. The raw DDL mirrors the CSV headers exactly, so all
    three tables share `geolocation_zip_code_prefix` — which is also the join key
    to `geolocation`. Keep this name; do not rename back.

14. **Sources: declare, never hardcode.** Every raw table is declared as a dbt
    source in `models/staging/_src_olist.yml` (source name `olist`, schema `raw`).
    Staging models read from `{{ source('olist', '<table>') }}` — never a
    hardcoded `raw.<table>`. This keeps the raw layer visible in the lineage
    graph, tracks the dependency, and puts the schema location in one place.

15. **Containerize by default.** Postgres, the CSV loader, and dbt all run in
    Docker (`docker-compose.yml`); a fresh clone needs only Docker. Run tasks with
    `docker compose run --rm loader ...` and `docker compose run --rm dbt dbt ...`.
    The connection is env-var driven, so the same `dbt/profiles.yml` works in a
    container (`DB_HOST=postgres`) and from the local venv (defaults to
    `localhost:5544`). The venv is kept only for editor integration and running
    lint/format — Docker is the source of truth for running the pipeline.

16. **Lint & format with sqlfluff (only).** `sqlfluff` (config in `dbt/.sqlfluff`:
    Postgres dialect + dbt templater) is the single tool for both linting and
    formatting SQL — no separate formatter. Run `sqlfluff fix models/` then
    `sqlfluff lint models/` before committing. The same `sqlfluff lint` is the
    intended CI gate (GitHub Actions later), so keeping models lint-clean locally
    means CI passes on the first run.

## 3. Git & Conventional Commits

Use **Conventional Commits** for every commit. Format:

```
<type>(<optional scope>): <short, imperative description>
```

**Types**
- `feat`     — a new capability (new DDL, new model, new loader feature)
- `fix`      — a bug fix
- `chore`    — setup / tooling / config (no product logic change)
- `docs`     — documentation only
- `refactor` — code change that isn't a feature or a fix
- `test`     — adding or changing tests
- `style`    — formatting only (no logic change)

**Rules**
- One logical change per commit (don't mix a feature and a docs edit).
- **Never one big commit that bundles unrelated changes** (e.g. `feat` + `feat`
  + `fix` together). Split the work into separate, focused commits — one type of
  change each — so the history stays clean and each commit is revertible on its
  own. Formatting-only runs get their own `style:` commit, separate from logic.
- Description in the imperative ("add", "fix", not "added"/"fixes").
- Keep the summary line short (~50 chars); add a body only if the *why* needs it.

**Examples for this project**
```
chore(repo): scaffold olist-de structure and gitignore
feat(ddl): add raw landing schema for the 9 source tables
feat(load): add idempotent csv loader reading connection from .env
docs(readme): document setup and raw -> dbt roadmap
chore(dbt): scaffold empty dbt project directory
fix(load): keep leading zeros in zip prefixes (load as text)
```

## 4. Comment style

Keep comments purposeful and minimal — this code is read by seniors.

- Comment the **why** or a non-obvious decision/quirk — never restate what the
  code plainly does.
- Good: `# 5432/5433 used by local Postgres, so expose on 5544`,
  `# truncate + reload keeps the load idempotent`,
  `# source keeps the original misspelling ("lenght")`.
- Bad (do not write): obvious/chatty comments like `# your Mac's port`,
  `# read the file`, `# connect to the database`, `# this is a loop`.
- One concise docstring per module/function is enough; no multi-paragraph
  teaching comments in the code.
- If the code is self-explanatory, no comment beats a redundant one.

## 5. Keeping these rules current

This file is the project's source of truth for *how* we work. Whenever we change
an approach, add a tool, introduce a new layer/convention, or make a decision
worth carrying forward, **update `skills.md` in the same change** — but only if
the rule is genuinely reusable. Judge before adding:

- Add it if a future contributor (or future you) would otherwise repeat a
  mistake or reinvent the decision (e.g. "sources, never hardcode", "run dbt via
  docker").
- Don't add one-off, obvious, or purely temporary notes — keep this list tight.
- Prefer editing an existing rule over adding a near-duplicate.

# Environmental Analytics — dbt on PostgreSQL

A dbt portfolio project on public water quality data from Lucas County, Ohio, on the
western shore of Lake Erie. It runs 100% locally: PostgreSQL in Docker, dbt Core via
pip. Anyone can clone it and run it in a few commands, with no cloud account and no
trial.

> **Current state (v1):** water quality only, from a real extract of the Water
> Quality Portal (Lucas County, OH, water media, 2020-2025, WQX 3.0 `basicPhysChem`
> profile, pulled 2026-10-17 with `scripts/download_wqp.py`). Air quality is out of
> scope for v1 (see ADR 003). Work in progress: incremental model justification,
> CI and published docs.

> **Scope note:** this is a portfolio project built on public data, not a client
> monitoring network. It uses a single source, the Water Quality Portal, which
> combines results from two providers: STORET and USGS.

---

## How to run

```bash
# 1. database
cp .env.example .env
docker compose up -d

# 2. dbt
python3 -m venv .venv
source .venv/bin/activate             # Windows: .venv\Scripts\activate
pip install -r requirements.txt
export $(grep -v '^#' .env | xargs)   # PowerShell: see the Windows section below

# 3. validate and build
dbt debug
dbt build
```

`dbt build` runs seeds, models and tests in a single pass. Expected output for
this version: `PASS=28 ERROR=0`.

Documentation and lineage graph:

```bash
dbt docs generate
dbt docs serve        # http://localhost:8080
```

### Port conflicts

PostgreSQL is exposed on host port `5434` (set via `DBT_PG_PORT` in `.env`) to
avoid clashing with a local PostgreSQL on the default `5432`. If `5434` is also
taken, change it in `.env` and re-run `docker compose up -d`.

### Windows / PowerShell

`export $(grep ...)` is bash. In PowerShell, load the variables like this:

```powershell
Get-Content .env | Where-Object {$_ -notmatch '^#' -and $_ -match '='} | ForEach-Object {
    $k,$v = $_ -split '=',2
    [Environment]::SetEnvironmentVariable($k, $v, 'Process')
}
```

Alternatively, run everything inside WSL2, which is the lowest-friction path.

---

## Architecture

```
seeds (CSV)  →  staging (view)  →  marts (star schema)  →  docs + BI
```

- **`seeds/`** — the source is loaded as a static CSV via `dbt seed`. This is a
  deliberate decision: building a custom ingestion pipeline is a different skill
  and would dilute the focus on dbt. `scripts/download_wqp.py` documents how the
  seed was produced; it is not an ingestion pipeline.
- **`models/staging/`** — cleanup only: trim, casing, renaming, typing, unit
  normalization and parsing of the two date formats found in the source. No
  business logic.
- **`models/marts/`** — star schema. `fct_measurements` (grain: one row per
  measurement result) points to `dim_site` and `dim_parameter` (parameter +
  sample fraction). The fact is incremental (`delete+insert` with a `unique_key`)
  and has an enforced contract: declared column types, plus primary key and
  not-null constraints on its keys.
- **`tests/`** — a singular test in SQL and a custom generic test in
  `tests/generic/` (`analysis_not_before_collection`: a lab cannot analyze a
  sample before it was collected). Generic tests (`unique`, `not_null`,
  `accepted_values`, `relationships`) live in the `.yml` files next to the
  models.

### Test severity policy

- **`error`** protects the model: keys, relationships and impossible values stop
  the build.
- **`warn`** flags changes in the source: a new parameter, sample fraction or data
  provider is reported, but does not block the build.

### Reading the lineage graph

- **No `source()` in the DAG.** The source is a dbt seed, so models use `ref()`.
  `source()` is for tables loaded outside dbt, which ADR 001 ruled out.
- **`dim_site` has no edge to the fact.** The fact keeps `site_code` as a
  natural key, and a `relationships` test enforces that every `site_code`
  exists in `dim_site`. dbt docs do not draw test dependencies.

## Decision log

Architecture decisions live in `docs/decisions/`:

- **ADR 001** — load the source as dbt seeds instead of building an ingestion
  pipeline, and how the Lucas County extract was chosen.
- **ADR 002** — grain of the fact table: one row per measurement result.
- **ADR 003** — v1 scope is water quality only.

## Why dbt Core 1.x and not Fusion

The Fusion engine (dbt Core 2.0) only supports Snowflake, BigQuery, Databricks
and Redshift. PostgreSQL is not on the list. Since this project needs to run
locally, with no cloud account and no expiring trial, it stays on 1.x. That is
why `requirements.txt` pins the versions. Without the pins, `pip install
dbt-postgres` pulls the 2.0 alpha and the project fails at parse time with
`dbt1005`.

## Known pitfalls

- **`dbt seed --full-refresh` drops the staging views.** Dropping a seed table
  is a `cascade` in PostgreSQL and takes the dependent views with it. After a
  full refresh, run `dbt build` (or `dbt run`) before running a mart on its own.
- **Dates as text.** Without `column_types` in `_seeds.yml`, dbt creates every
  column as `text`, and the incremental filter ends up comparing a string to a
  date.
- **Incremental model after a data swap.** `fct_measurements` only loads rows with
  a `collected_date` greater than the latest one already loaded. After replacing a
  seed, run `dbt build --full-refresh`, otherwise older rows are skipped silently
  and the build still passes.
- **WQP non-detects.** About 3.6% of water results have no numeric value (mostly
  "Not Detected"). They are kept with a null value and a detection condition, not
  imputed.
- **Partial responses from the portal.** The Water Quality Portal intermittently
  returns only part of the USGS results for the same query. The download script
  refuses to overwrite the seed with a smaller response (details in ADR 001).
- **Two date formats in one column.** The lab analysis date mixes ISO dates and a
  Java-style string (`Tue May 25 00:00:00 UTC 2021`). The seed keeps it as text,
  and staging parses both. A parser for ISO only would leave 36 rows out of the
  date test without any warning.
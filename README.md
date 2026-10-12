# Environmental Analytics — dbt on PostgreSQL

A dbt portfolio project built on multi-matrix environmental data (groundwater,
surface water, air). It runs 100% locally: PostgreSQL in Docker, dbt Core via pip.
Anyone can clone it and run it in a few commands, with no cloud account and no trial.

> **Current state:** water quality runs on a real extract from the Water Quality
> Portal (Lucas County, OH, water media, 2020-2025, WQX 3.0 `basicPhysChem`
> profile, pulled 2026-10-12 with `scripts/download_wqp.py`). The air quality seed
> is still a smoke-test placeholder and will be replaced by an OpenAQ extract.

> **Note:** this is a multi-source composition built for portfolio purposes, not
> an integrated monitoring network from a single client. The sources come from
> different origins and regions.

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
this version: `PASS=19 ERROR=0`.

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
seeds (CSV)  →  staging (view, 1:1 per source)  →  marts (table/incremental)  →  docs + BI
```

- **`seeds/`** — sources are loaded as static CSVs via `dbt seed`. This is a
  deliberate decision: building a custom ingestion pipeline is a different skill
  and would dilute the focus on dbt.
- **`models/staging/`** — one model per source. Cleanup only: trim, casing,
  renaming, typing. No business logic.
- **`models/marts/`** — cross-matrix joins and aggregation. `fct_measurements`
  is incremental (`delete+insert` with a `unique_key`).
- **`tests/`** — singular tests written in SQL. Generic tests (`unique`,
  `not_null`, `accepted_values`) live in the `.yml` files next to the models.

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
- **CSV columns with spaces in the name** (`" parameter "`) need double quotes
  in SQL and in the `column_types` key. It is worth cleaning the CSV header at
  the source.
- **Dates as text.** Without `column_types` in `_seeds.yml`, dbt creates every
  column as `text`, and the incremental filter ends up comparing a string to a
  date.
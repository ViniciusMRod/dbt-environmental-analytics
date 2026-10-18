# ADR 001: Load sources as dbt seeds instead of building an ingestion pipeline

- Status: Accepted
- Date: 2026-10-12

## Context

The project exists to demonstrate dbt: modeling, testing, documentation and an
incremental model. Getting data into PostgreSQL is a separate skill (extraction,
scheduling, retries, schema drift), and building it would dilute the focus.

The first scope was groundwater and surface water from the state of Maranhao, Brazil.
The Water Quality Portal (WQP) only serves United States data: a country-code query
for Brazil returns 0 monitoring sites, while Ohio alone returns 42,748.

## Decision

1. Sources are committed as static CSVs and loaded with `dbt seed`.
   `scripts/download_wqp.py` documents how the water seed was produced, but it is a
   provenance script, not a pipeline.
2. The water extract is Lucas County, Ohio (Lake Erie shoreline, site of recurring
   cyanobacterial blooms), water media only, 2020-2025, eight common parameters
   (pH, dissolved oxygen, specific conductance, turbidity, nitrate, phosphorus, iron,
   manganese). It uses the WQX 3.0 `basicPhysChem` profile, because USGS data added
   after March 2024 is only served there.
3. Sediment results (about 9% of the raw extract) are out of scope for v1. They are
   reported in mg/kg while the same parameters in water are in ug/L, so mixing them in
   one column would produce meaningless averages.

Extract: 2,980 water results, 51 monitoring locations, 2020-01-07 to 2025-12-17,
about 0.7 MB (STORET 1,543 rows, USGS 1,437).

## Alternatives considered

- Statewide Ohio extract: about 75k results, large for a seed and slow to load.
- Load with `psql \copy` and declare a dbt `source()`: closer to production, but it
  turns the project into an ingestion exercise.
- Brazilian water quality data instead of WQP: would keep the Maranhao story, but
  needs a new source study and a larger scope than the plan allows.

## Consequences

- The dataset is a point-in-time snapshot. An earlier run of the same query returned
  fewer rows (1,923) than later ones (2,980) and the difference was not explained,
  so the extraction date is recorded in the README.
- Re-running the script can change the seed. After replacing a seed, an incremental
  model needs `dbt build --full-refresh`.
- The project is a multi-source composition for portfolio purposes, not a single
  integrated monitoring network.
- The portal intermittently returns an incomplete response for the same query:
  all STORET results but only 97 of 1,437 USGS results (1,640 vs 2,980 water
  rows). The partial response is a strict subset of the complete one. Requesting
  the USGS provider alone (`providers=NWIS`) also returns 97 rows, so per-provider
  requests do not help. The cause is not established. `scripts/download_wqp.py`
  refuses to overwrite the seed with a smaller response.
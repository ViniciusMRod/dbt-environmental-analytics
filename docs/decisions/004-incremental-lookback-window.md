# ADR 004: Incremental fact with a lookback window

- Status: Accepted
- Date: 2026-10-24

## Context

`fct_measurements` is the main mart (grain in ADR 002). The Water Quality Portal
keeps publishing results over time, and a result can be published after results
with later collection dates. The first version loaded only rows with
`collected_date > max(collected_date)`.

Experiment on 2026-10-24, with all 2,980 rows loaded: two results were deleted
from the fact to simulate late arrivals. Result A was collected on the latest
date (2025-12-17) and result B 13 days earlier (2025-12-04). The model was then
run with each filter:

| Filter | Rows reprocessed | Total after the run | Recovered |
|---|---|---|---|
| `> max(collected_date)` | 0 | 2,978 | none |
| `>= max(collected_date)` | 11 | 2,979 | A |
| 30-day lookback window | 33 | 2,980 | A and B |

A second run with the 30-day window reprocessed the same 33 rows and kept 2,980
rows. The `unique` test on `result_id` passed.

## Decision

- Materialization: incremental, strategy `delete+insert`, `unique_key` =
  `result_id` (the grain key).
- Filter: reprocess a window, `collected_date >= max(collected_date) - lookback_days`,
  with `lookback_days` as a dbt variable (default 30).
- `delete+insert` makes reprocessing idempotent: rows in the window are deleted
  and reinserted, never duplicated.

## Why incremental at all

With a static seed of 2,980 rows, a full rebuild takes a fraction of a second, so
the incremental model brings no performance gain in v1. It stays because the
source behaves like a stream of published results with late arrivals, and the
model documents how to load that kind of source without rebuilding everything.

## Alternatives considered

- `>` on the latest date: loses late results with the same date (shown above).
- `>=` on the latest date: fixes that case, but still loses late results with an
  earlier date (shown above).
- Full rebuild on every run: simple and correct, and the right choice if the
  dataset stays this small.
- Filter on a publication or last-changed date instead of `collected_date`: the
  right key for late arrivals, but the seed does not keep such a column.

## Consequences

- Results that arrive more than 30 days late, by collection date, are not loaded
  by a normal run. They need `dbt build --full-refresh`.
- 30 days is a starting point, not a value measured from the portal's
  publication lag. It can be changed with `--vars "{lookback_days: N}"`.
- Every normal run reprocesses the window (33 rows in this extract).
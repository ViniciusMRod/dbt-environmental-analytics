{% docs __overview__ %}

# Environmental Analytics — water quality in Lucas County, Ohio

A dbt project on public water quality data from the Water Quality Portal:
2,980 measurement results from 51 monitoring sites on the western shore of
Lake Erie, 2020-2025.

## Model

- `fct_measurements` — one row per measurement result. Incremental, with a
  30-day lookback window and an enforced contract.
- `dim_site` — 51 monitoring locations.
- `dim_parameter` — 17 combinations of parameter and sample fraction.

Click the blue icon in the bottom-right corner to see the lineage graph.

## Decisions

The reasoning behind the grain, the scope, the tests and the incremental
strategy is in the decision log (ADRs 001 to 004) in the
[GitHub repository](https://github.com/ViniciusMRod/dbt-environmental-analytics).

{% enddocs %}
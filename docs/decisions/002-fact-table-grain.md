# ADR 002: Grain of the fact table

- Status: Accepted for water. Open for air (see Consequences).
- Date: 2026-10-12

## Context

The WQP extract has one row per measurement result. One sampling activity produces
several rows (one per parameter), and the same parameter can appear more than once
within an activity: 436 activity + parameter pairs have more than one result. 
Sample fraction explains 98 of those pairs (for example, filtered vs total 
recoverable iron). The other 338 share the same fraction. The extract does not keep 
the columns that would explain them (activity type, analytical method), so their 
cause is not established. `result_measureidentifier` is unique across all 2,980 rows.

## Decision

The grain of `fct_measurements` is one row per measurement result, identified by the
WQP result identifier (tested with `unique` and `not_null`). A result belongs to one
monitoring location, one sampling activity and one parameter.

Planned star schema:

- Fact `fct_measurements`: result key, date, site key, parameter key, result value,
  unit, detection condition, `is_quantified`, data provider, activity id (degenerate
  dimension).
- Dimension `dim_site`: site code, name, type, latitude, longitude, HUC8 watershed.
- Dimension `dim_parameter`: parameter name and sample fraction. The fraction changes
  what a value means (filtered, total recoverable and dissolved iron are different
  measurements), so it belongs to the parameter. The unit stays on the fact, because
  the same parameter arrives in different units (turbidity as NTU, FNU and NTRU, which
  are not strictly interchangeable).

Non-detects keep a null `result_value`, their detection condition and an
`is_quantified` flag. 108 of 2,980 results (3.6%) have no numeric value, and 103 of
those are "Not Detected".

## Alternatives considered

- Grain at sampling activity (one row per visit, parameters as columns): easier to
  read, but 436 activity + parameter pairs would collapse several results into one,
  and detection conditions would be lost.
- Substitute half the detection limit for non-detects, a common convention in
  environmental work. It is feasible here, since all 108 non-detects carry a detection
  limit (only 491 of 2,980 rows do overall). Rejected for v1 because it puts invented
  numbers next to measured ones. If needed later, it should be a separate derived
  column, not a replacement of `result_value`.

## Consequences

- Air quality from OpenAQ will probably not share this grain (typically a reading per
  location, parameter and timestamp). Whether both matrices fit one fact table or need
  separate facts is decided when the air extract is chosen.
- `sample_id` in staging holds the result identifier. It is renamed to `result_id`
  when the marts become a star schema.
- Averages across results of the same parameter and day may mix duplicates of unknown
  origin until the cause of the 436 repeated pairs is understood.
- Results must not be averaged across sample fractions. `sample_fraction` is added to
  staging in the next iteration.

## Update (2026-10-15): implemented

- `fct_measurements`, `dim_site` (51 rows) and `dim_parameter` (17 rows) are built
  as described above. `relationships` tests link the fact to both dimensions.
- `sample_id` was renamed to `result_id` in staging.
- `sample_fraction` is in staging and in `dim_parameter`, with "not reported"
  when the source leaves it empty (49% of results).
- Air quality was removed from the fact. It returns once its grain is decided.

## Update (2026-10-20): air out of scope

- Air quality is out of scope for v1 (see ADR 003). The fact table covers water
  only, and the open question about the air grain is closed for this version.
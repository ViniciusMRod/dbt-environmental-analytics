# ADR 003: v1 scope is water quality only

- Status: Accepted
- Date: 2026-10-23

## Context

The original plan paired water quality from the Water Quality Portal (WQP) with
air quality from OpenAQ, to mirror a multi-matrix environmental monitoring project.

The water extract covers Lucas County, Ohio, on the western shore of Lake Erie.
The documented water quality problem there is recurring cyanobacterial blooms,
linked mainly to phosphorus and nitrogen loading from the Maumee River basin.
OpenAQ measures air pollutants such as particulate matter, ozone and nitrogen
dioxide. The only link to the water question would be atmospheric nitrogen
deposition, which OpenAQ does not measure.

The air seed in the repository was a 4-row smoke-test placeholder.

## Decision

v1 covers water quality only. Air quality moves to a Phase 2 backlog. The air
placeholder (seed, staging model and its tests) was removed, along with the
`matrix` column, which held the same value in every row.

## Alternatives considered

- Keep OpenAQ: preserves the multi-matrix story, but adds a source with a
  different grain (readings per location, parameter and timestamp) and no
  analytical link to the water question.
- Use the sediment results from the same WQP query (282 rows in the raw
  response): same source and grain, and metals in sediment relate to water
  quality. Deferred, because it needs a unit decision (mg/kg in sediment vs
  ug/L in water) and v1 does not need it.

## Consequences

- The project is a single-source model: WQP, with STORET and USGS as providers.
  It is no longer described as a multi-source composition.
- The open question about the air grain in ADR 002 is closed for v1.
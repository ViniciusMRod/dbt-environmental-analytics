-- One row per parameter and sample fraction. The parameter name alone repeats
-- (filtered and total recoverable iron are different measurements), so the key
-- is a hash of both columns.
select distinct
    md5(parameter || '|' || sample_fraction) as parameter_key,
    parameter,
    sample_fraction
from {{ ref('stg_water_quality') }}
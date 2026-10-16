-- Singular test: a negative concentration is physically impossible.
-- Returning 0 rows = pass.

select
    result_id,
    parameter_key,
    result_value
from {{ ref('fct_measurements') }}
where result_value < 0
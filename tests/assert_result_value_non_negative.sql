-- Singular test: a negative concentration is physically impossible.
-- Returning 0 rows = pass.

select
    sample_id,
    matrix,
    parameter,
    result_value
from {{ ref('fct_measurements') }}
where result_value < 0
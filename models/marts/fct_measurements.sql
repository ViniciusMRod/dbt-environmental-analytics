{{
    config(
        materialized='incremental',
        unique_key='result_id',
        incremental_strategy='delete+insert'
    )
}}

-- Grain: one row per measurement result (docs/decisions/002-fact-table-grain.md).
-- Water only for now. Air quality joins once the OpenAQ extract and its grain
-- are decided.

with results as (

    select * from {{ ref('stg_water_quality') }}

    {% if is_incremental() %}
    -- only process rows collected after the latest load (revisited in S4)
    where collected_date > (select coalesce(max(collected_date), date '1900-01-01') from {{ this }})
    {% endif %}

),

parameters as (

    select * from {{ ref('dim_parameter') }}

)

select
    results.result_id,
    results.collected_date,
    results.site_code,
    parameters.parameter_key,
    results.result_value,
    results.unit,
    results.detection_condition,
    results.is_quantified,
    results.data_provider,
    results.activity_id,
    current_timestamp as dbt_loaded_at
from results
left join parameters
    on  results.parameter = parameters.parameter
    and results.sample_fraction = parameters.sample_fraction
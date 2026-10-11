{{
    config(
        materialized='incremental',
        unique_key='sample_id',
        incremental_strategy='delete+insert'
    )
}}

with unioned as (

    select
        sample_id,
        collected_date,
        site_code,
        parameter,
        result_value,
        unit,
        matrix
    from {{ ref('stg_water_quality') }}

    union all

    select
        sample_id,
        collected_date,
        site_code,
        parameter,
        result_value,
        unit,
        matrix
    from {{ ref('stg_air_quality') }}

),

final as (

    select
        sample_id,
        collected_date,
        site_code,
        matrix,
        parameter,
        result_value,
        unit,
        current_timestamp as dbt_loaded_at
    from unioned

    {% if is_incremental() %}

    -- only process rows collected after the latest load
    where collected_date > (select coalesce(max(collected_date), date '1900-01-01') from {{ this }})

    {% endif %}

)

select * from final
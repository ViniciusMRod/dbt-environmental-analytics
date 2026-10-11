with source as (

    select * from {{ ref('raw_water_quality') }}

),

renamed as (

    select
        sample_id                                   as sample_id,
        collected_at                                as collected_date,
        upper(trim(site_code))                      as site_code,
        lower(trim(" parameter "))                  as parameter,
        result_value                                as result_value,
        lower(trim(unit))                           as unit,
        'water'                                     as matrix
    from source

)

select * from renamed

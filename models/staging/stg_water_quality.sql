with source as (

    select * from {{ ref('raw_wqp_results') }}

),

renamed as (

    select
        -- Grain: one row per measurement result (one parameter, at one site,
        -- in one sampling activity).
        result_measureidentifier                         as result_id,
        activity_activityidentifier                      as activity_id,
        activity_startdate                               as collected_date,
        case
            when labinfo_analysisstartdate ~ '^\d{4}-\d{2}-\d{2}'
                then labinfo_analysisstartdate::date
            when labinfo_analysisstartdate ~ '^[A-Za-z]{3} [A-Za-z]{3} \d{2} '
                then to_date(substring(labinfo_analysisstartdate from 5 for 6) || ' ' || right(labinfo_analysisstartdate, 4), 'Mon DD YYYY')
        end                                              as analysis_date,
        upper(trim(location_identifier))                 as site_code,
        trim(location_name)                              as site_name,
        lower(trim(location_type))                       as site_type,
        location_latitudestandardized                    as latitude,
        location_longitudestandardized                   as longitude,
        location_huceightdigitcode                       as huc8,
        lower(trim(result_characteristic))               as parameter,
        result_measure                                   as result_value,
        coalesce(nullif(nullif(lower(trim(result_samplefraction)), ''), 'none'), 'not reported') as sample_fraction,
        case
            when lower(trim(result_characteristic)) = 'ph' then 'standard units'
            when lower(trim(result_measureunit)) in ('umho/cm', 'us/cm') then 'us/cm'
            else nullif(nullif(lower(trim(result_measureunit)), ''), 'none')
        end                                              as unit,
        nullif(nullif(trim(result_resultdetectioncondition), ''), 'None') as detection_condition,
        (result_measure is not null)                     as is_quantified,
        lower(trim(providername))                        as data_provider
    from source

)

select * from renamed

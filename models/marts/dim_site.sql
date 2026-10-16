-- One row per monitoring location.
select distinct
    site_code,
    site_name,
    site_type,
    latitude,
    longitude,
    huc8
from {{ ref('stg_water_quality') }}
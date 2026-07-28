-- One representative point per zip: Brazil-bbox filter (drops bad coords), then mean lat/lng.
with geo as (

    select * from {{ ref('stg_geolocation') }}
    where
        latitude between -34 and 6
        and longitude between -74 and -33

)

select
    zip_code_prefix,
    avg(latitude) as latitude,
    avg(longitude) as longitude,
    mode() within group (order by geolocation_city) as city,
    mode() within group (order by geolocation_state) as state
from geo
group by zip_code_prefix

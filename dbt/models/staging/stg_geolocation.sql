-- Staging model: zip-code geolocation points. Casts lat/lng to numeric.
select
    geolocation_zip_code_prefix::varchar(10) as zip_code_prefix,
    nullif(geolocation_lat, '')::numeric as latitude,
    nullif(geolocation_lng, '')::numeric as longitude,
    geolocation_city::varchar(100) as geolocation_city,
    geolocation_state::varchar(2) as geolocation_state
from {{ source("olist", "geolocation") }}

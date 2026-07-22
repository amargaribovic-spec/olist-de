-- Staging model: zip-code geolocation points. Casts lat/lng to numeric.
select
    geolocation_zip_code_prefix as zip_code_prefix,
    nullif(geolocation_lat, '')::numeric as latitude,
    nullif(geolocation_lng, '')::numeric as longitude,
    geolocation_city,
    geolocation_state
from {{ source("olist", "geolocation") }}

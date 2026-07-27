-- Staging model: sellers. Renames the zip column to match the join key convention.
select
    seller_id::varchar as seller_id,
    geolocation_zip_code_prefix::varchar as zip_code_prefix,
    seller_city::varchar as seller_city,
    seller_state::varchar as seller_state
from {{ source("olist", "sellers") }}

-- Staging model: sellers. Renames the zip column to match the join key convention.
select
    seller_id::varchar(32) as seller_id,
    geolocation_zip_code_prefix::varchar(10) as zip_code_prefix,
    seller_city::varchar(100) as seller_city,
    seller_state::varchar(2) as seller_state
from {{ source("olist", "sellers") }}

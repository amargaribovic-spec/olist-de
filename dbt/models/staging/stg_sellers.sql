-- Staging model: sellers. Renames the zip column to match the join key convention.
select
    seller_id, geolocation_zip_code_prefix as zip_code_prefix, seller_city, seller_state
from {{ source("olist", "sellers") }}

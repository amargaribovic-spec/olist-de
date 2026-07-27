-- Staging model: light cleanup of the raw customers table.
select
    customer_id::varchar as customer_id,
    customer_unique_id::varchar as customer_unique_id,
    geolocation_zip_code_prefix::varchar as zip_code_prefix,
    customer_city::varchar as customer_city,
    customer_state::varchar as customer_state
from {{ source("olist", "customers") }}

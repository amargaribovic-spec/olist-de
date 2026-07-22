-- Staging model: light cleanup of the raw customers table.
select
    customer_id,
    customer_unique_id,
    geolocation_zip_code_prefix as zip_code_prefix,
    customer_city,
    customer_state
from {{ source("olist", "customers") }}

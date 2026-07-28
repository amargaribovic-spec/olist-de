-- Staging model: light cleanup of the raw customers table.
select
    customer_id::varchar(32) as customer_id,
    customer_unique_id::varchar(32) as customer_unique_id,
    geolocation_zip_code_prefix::varchar(10) as zip_code_prefix,
    customer_city::varchar(100) as customer_city,
    customer_state::varchar(2) as customer_state
from {{ source("olist", "customers") }}

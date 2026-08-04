-- Staging model: light cleanup of the raw customers table.
-- Append-only raw → keep the latest row per customer_id.
with source as (

    SELECT
        *,
        row_number() over (partition by customer_id order by _loaded_at desc) as _rn
    from {{ source("olist", "customers") }}

)

select
    customer_id::varchar(32) as customer_id,
    customer_unique_id::varchar(32) as customer_unique_id,
    geolocation_zip_code_prefix::varchar(10) as zip_code_prefix,
    customer_city::varchar(100) as customer_city,
    customer_state::varchar(2) as customer_state,
    _loaded_at
from source
where _rn = 1

-- Staging model: sellers. Renames the zip column to match the join key convention.
-- Append-only raw → keep the latest row per seller_id.
with source as (

    select
        *,
        row_number() over (partition by seller_id order by _loaded_at desc) as _rn
    from {{ source("olist", "sellers") }}

)

select
    seller_id::varchar(32) as seller_id,
    geolocation_zip_code_prefix::varchar(10) as zip_code_prefix,
    seller_city::varchar(100) as seller_city,
    seller_state::varchar(2) as seller_state,
    _loaded_at
from source
where _rn = 1

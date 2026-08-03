-- Staging model: Portuguese -> English product category names (lookup table).
-- Append-only raw → keep the latest row per product_category_name.
with source as (

    select
        *,
        row_number() over (
            partition by product_category_name order by _loaded_at desc
        ) as _rn
    from {{ source("olist", "product_category_translation") }}

)

select
    product_category_name::varchar(100) as product_category_name,
    product_category_name_english::varchar(100) as product_category_name_english,
    _loaded_at
from source
where _rn = 1

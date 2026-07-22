-- Staging model: one row per item within an order. Casts numeric/timestamp fields.
select
    order_id,
    order_item_id,
    product_id,
    seller_id,
    nullif(shipping_limit_date, '')::timestamp as shipping_limit_date,
    nullif(price, '')::numeric as price,
    nullif(freight_value, '')::numeric as freight_value
from {{ source("olist", "order_items") }}

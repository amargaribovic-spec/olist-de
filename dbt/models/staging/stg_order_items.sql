-- Staging model: one row per item within an order.
-- Surrogate key from the composite natural key (order_id, order_item_id).
select
    ({{ dbt_utils.generate_surrogate_key(['order_id', 'order_item_id']) }})::varchar(32)
        as order_item_sk,
    order_id::varchar(32) as order_id,
    order_item_id::int as order_item_id,
    product_id::varchar(32) as product_id,
    seller_id::varchar(32) as seller_id,
    nullif(shipping_limit_date, '')::timestamp as shipping_limit_date,
    nullif(price, '')::numeric as price,
    nullif(freight_value, '')::numeric as freight_value
from {{ source("olist", "order_items") }}

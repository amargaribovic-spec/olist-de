{{ config(materialized="table") }}
-- Order-level item totals: sum of price and freight per order. One row per order.
select
    order_id,
    sum(price) as order_total,
    sum(freight_value) as freight_total,
    count(*) as item_count
from {{ ref('stg_order_items') }}
group by order_id

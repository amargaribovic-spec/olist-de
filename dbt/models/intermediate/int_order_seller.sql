{{ config(materialized="table") }}
-- Each order's seller = the seller of its first item (order_item_id = 1). One row per order.
with items as (

    select
        order_id,
        seller_id,
        order_item_id
    from {{ ref('stg_order_items') }}

),

ranked as (

    select
        order_id,
        seller_id,
        row_number() over (partition by order_id order by order_item_id) as rn
    from items

)

select
    order_id,
    seller_id
from ranked
where rn = 1

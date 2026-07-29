{{ config(materialized="table") }}
-- Per order: customer and seller coordinates (customer via the order, seller via
-- the order's first-item seller). One row per order.
with orders as (

    select
        order_id,
        customer_id
    from {{ ref('stg_orders') }}

),

order_seller as (

    select
        order_id,
        seller_id
    from {{ ref('int_order_seller') }}

),

cust as (

    select
        customer_id,
        customer_state,
        latitude,
        longitude
    from {{ ref('int_customer_geo') }}

),

sell as (

    select
        seller_id,
        seller_state,
        latitude,
        longitude
    from {{ ref('int_seller_geo') }}

)

select
    o.order_id,
    cust.customer_state,
    sell.seller_state,
    cust.latitude as customer_latitude,
    cust.longitude as customer_longitude,
    sell.latitude as seller_latitude,
    sell.longitude as seller_longitude
from orders as o
inner join order_seller as os on o.order_id = os.order_id
inner join cust on o.customer_id = cust.customer_id
inner join sell on os.seller_id = sell.seller_id

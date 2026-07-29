{{ config(materialized="table") }}
-- Order items enriched with customer region and seller region (via the state->region seed).
-- One row per order item.
with items as (

    select
        order_id,
        seller_id,
        category,
        price,
        freight_value
    from {{ ref('int_order_items_categorized') }}

),

orders as (

    select
        order_id,
        customer_id
    from {{ ref('stg_orders') }}

),

customers as (

    select
        customer_id,
        customer_state
    from {{ ref('stg_customers') }}

),

sellers as (

    select
        seller_id,
        seller_state
    from {{ ref('stg_sellers') }}

),

region as (

    select
        state,
        region
    from {{ ref('state_region') }}

)

select
    i.order_id,
    i.category,
    i.price,
    i.freight_value,
    cr.region as customer_region,
    sr.region as seller_region
from items as i
inner join orders as o on i.order_id = o.order_id
inner join customers as c on o.customer_id = c.customer_id
inner join sellers as s on i.seller_id = s.seller_id
left join region as cr on c.customer_state = cr.state
left join region as sr on s.seller_state = sr.state

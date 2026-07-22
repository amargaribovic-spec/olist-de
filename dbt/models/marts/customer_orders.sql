-- Your first model built on OTHER models via ref().
-- dbt reads the ref() calls to work out that stg_customers and stg_orders
-- must be built before this one. Materialized as a table (see dbt_project.yml).
with
    customers as (select * from {{ ref("stg_customers") }}),

    orders as (select * from {{ ref("stg_orders") }}),

    order_stats as (

        select
            customer_id,
            count(order_id) as number_of_orders,
            min(order_purchase_timestamp) as first_order,
            max(order_purchase_timestamp) as most_recent_order
        from orders
        group by customer_id

    )

select
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    coalesce(o.number_of_orders, 0) as number_of_orders,
    o.first_order,
    o.most_recent_order
from customers as c
left join order_stats as o on c.customer_id = o.customer_id

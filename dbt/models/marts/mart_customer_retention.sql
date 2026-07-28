-- NB03: repeat-purchase behaviour, one row per customer (person).
with orders as (

    select * from {{ ref('int_orders_with_unique_customer') }}

),

ranked as (

    select
        customer_unique_id,
        order_purchase_timestamp,
        row_number() over (
            partition by customer_unique_id
            order by order_purchase_timestamp
        ) as order_num
    from orders

)

select
    customer_unique_id,
    count(*) as number_of_orders,
    count(*) > 1 as is_repeat,
    min(order_purchase_timestamp) as first_order_at,
    min(order_purchase_timestamp) filter (where order_num = 2) as second_order_at,
    extract(
        epoch from (
            min(order_purchase_timestamp) filter (where order_num = 2)
            - min(order_purchase_timestamp)
        )
    ) / 86400 as days_to_second_order
from ranked
group by customer_unique_id

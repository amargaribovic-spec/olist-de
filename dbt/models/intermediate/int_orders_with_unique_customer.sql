-- Orders with the person-level customer_unique_id attached.
with orders as (

    select * from {{ ref('stg_orders') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

)

select
    orders.order_id,
    orders.customer_id,
    customers.customer_unique_id,
    orders.order_status,
    orders.order_purchase_timestamp
from orders
left join customers on orders.customer_id = customers.customer_id

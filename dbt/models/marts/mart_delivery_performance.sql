-- NB01: valid delivered orders with their delivery metrics.
with delivery as (

    select * from {{ ref('int_order_delivery') }}
    where is_valid_timeline

)

select
    order_id,
    customer_id,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    days_approval,
    days_carrier,
    days_last_mile,
    days_total,
    days_delay,
    is_late
from delivery

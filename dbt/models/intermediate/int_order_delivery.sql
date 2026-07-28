-- Intermediate: delivery-stage metrics, one row per DELIVERED order.
-- Reused by the delivery, satisfaction, distance, region and time-to-review marts.
-- We FLAG invalid timelines (nulls / out-of-order timestamps) rather than drop them,
-- so each downstream mart decides whether to filter.
with orders as (

    select * from {{ ref('stg_orders') }}
    where order_status = 'delivered'

)

select
    order_id,
    customer_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    -- stage durations, in days (interval -> seconds -> days)
    extract(epoch from (order_approved_at - order_purchase_timestamp)) / 86400
        as days_approval,
    extract(epoch from (order_delivered_carrier_date - order_approved_at)) / 86400
        as days_carrier,
    extract(epoch from (order_delivered_customer_date - order_delivered_carrier_date)) / 86400
        as days_last_mile,
    extract(epoch from (order_delivered_customer_date - order_purchase_timestamp)) / 86400
        as days_total,
    extract(epoch from (order_delivered_customer_date - order_estimated_delivery_date)) / 86400
        as days_delay,

    -- delivered later than promised
    order_delivered_customer_date > order_estimated_delivery_date as is_late,

    -- all four timestamps present AND in a plausible order (NB01 cleaning):
    -- approved after purchase, carrier >= approved + 5 min, customer >= carrier + 20 min
    (
        order_approved_at is not null
        and order_delivered_carrier_date is not null
        and order_delivered_customer_date is not null
        and order_estimated_delivery_date is not null
        and order_approved_at >= order_purchase_timestamp
        and order_delivered_carrier_date >= order_approved_at + interval '5 minutes'
        and order_delivered_customer_date >= order_delivered_carrier_date + interval '20 minutes'
    ) as is_valid_timeline

from orders

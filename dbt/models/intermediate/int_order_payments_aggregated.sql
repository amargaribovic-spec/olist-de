-- Payments rolled up to one row per order.
with payments as (

    select * from {{ ref('stg_order_payments') }}

)

select
    order_id,
    count(*) as number_of_payments,
    count(distinct payment_type) as number_of_payment_types,
    max(payment_sequential) as max_payment_sequential,
    max(payment_installments) as max_installments,
    sum(payment_value) as total_payment_value,
    string_agg(distinct payment_type, ', ' order by payment_type) as payment_types
from payments
group by order_id

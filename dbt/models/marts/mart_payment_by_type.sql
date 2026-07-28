-- NB04: payment-method mix per type ('not_defined' excluded).
with payments as (

    select * from {{ ref('stg_order_payments') }}
    where payment_type != 'not_defined'

)

select
    payment_type,
    count(*) as transaction_count,
    count(distinct order_id) as unique_orders,
    sum(payment_value) as total_value,
    round(avg(payment_value), 2) as avg_value,
    round(avg(payment_installments), 2) as avg_installments,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as transaction_pct,
    round(100.0 * sum(payment_value) / sum(sum(payment_value)) over (), 2) as revenue_pct
from payments
group by payment_type
order by transaction_count desc

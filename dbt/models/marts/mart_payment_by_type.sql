-- NB04: payment-method mix per type. Reads the shared cleaned set
-- (int_payments_cleaned already drops 'not_defined' + invalid installments),
-- so this mart and mart_payment_by_order see identical input.
with payments as (

    select * from {{ ref('int_payments_cleaned') }}

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

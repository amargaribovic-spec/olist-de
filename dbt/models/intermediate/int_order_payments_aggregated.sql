-- Payments rolled up to one row per order (cleaned rows only).
--
-- number_of_payments follows NB04's definition: the highest payment_sequential
-- for the order, NOT the surviving row count. An order's payment sequence can
-- have gaps, and the analysis counts the sequence — so an order reaching
-- sequential 2 is "multi-payment" even if only one row survives cleaning.
with payments as (

    select * from {{ ref('int_payments_cleaned') }}

)

select
    order_id,
    max(payment_sequential) as number_of_payments,
    count(distinct payment_type) as number_of_payment_types,
    max(payment_installments) as max_installments,
    sum(payment_value) as total_payment_value,
    string_agg(distinct payment_type, ', ' order by payment_type) as payment_types,
    max(_loaded_at) as _loaded_at
from payments
group by order_id

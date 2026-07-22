-- Staging model: payment records per order. Casts numeric fields.
select
    order_id,
    nullif(payment_sequential, '')::int as payment_sequential,
    payment_type,
    nullif(payment_installments, '')::int as payment_installments,
    nullif(payment_value, '')::numeric as payment_value
from {{ source("olist", "order_payments") }}

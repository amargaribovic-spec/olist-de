-- Staging model: payment records per order.
-- Surrogate key from the composite natural key (order_id, payment_sequential).
-- Append-only raw → keep the latest row per (order_id, payment_sequential).
with source as (

    select
        *,
        row_number() over (
            partition by order_id, payment_sequential order by _loaded_at desc
        ) as _rn
    from {{ source("olist", "order_payments") }}

)

select
    ({{ dbt_utils.generate_surrogate_key(['order_id', 'payment_sequential']) }})::varchar(32)
        as payment_sk,
    order_id::varchar(32) as order_id,
    nullif(payment_sequential, '')::int as payment_sequential,
    payment_type::varchar(20) as payment_type,
    nullif(payment_installments, '')::int as payment_installments,
    nullif(payment_value, '')::numeric as payment_value,
    _loaded_at
from source
where _rn = 1

-- NB04 (per order): payment behaviour per order — multi-payment / multi-type flags.
with payments as (

    select * from {{ ref('int_order_payments_aggregated') }}

)

select
    order_id,
    number_of_payments,
    number_of_payment_types,
    max_installments,
    total_payment_value,
    payment_types,
    number_of_payments > 1 as is_multi_payment,
    number_of_payment_types > 1 as is_multi_type
from payments

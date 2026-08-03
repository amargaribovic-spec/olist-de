{{ config(materialized="incremental", unique_key="order_id",
          incremental_strategy="merge", on_schema_change="sync_all_columns") }}
-- NB04 (per order): payment behaviour per order — multi-payment / multi-type flags.
-- Incremental: merge new/updated orders (by _loaded_at) keyed on order_id.
with payments as (

    select * from {{ ref('int_order_payments_aggregated') }}
    where _loaded_at > {{ incremental_watermark() }}

)

select
    order_id,
    number_of_payments,
    number_of_payment_types,
    max_installments,
    total_payment_value,
    payment_types,
    _loaded_at,
    number_of_payments > 1 as is_multi_payment,
    number_of_payment_types > 1 as is_multi_type
from payments

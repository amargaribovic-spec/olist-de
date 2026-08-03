{{ config(materialized="incremental", unique_key="order_id",
          incremental_strategy="merge", on_schema_change="sync_all_columns") }}
-- NB01: valid delivered orders with their delivery metrics.
-- Incremental: merge new/updated orders (by _loaded_at) keyed on order_id.
with delivery as (

    select * from {{ ref('int_order_delivery') }}
    where
        is_valid_timeline
        and _loaded_at > {{ incremental_watermark() }}

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
    is_late,
    _loaded_at
from delivery

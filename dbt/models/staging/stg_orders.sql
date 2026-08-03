-- Staging model: light cleanup of the raw orders table.
-- Raw is append-only, so we keep only the latest row per order_id (an updated
-- order arrives as a new row with a later _loaded_at). Empty-string timestamps
-- become NULL so the ::timestamp casts don't error on missing values.
with source as (

    select
        *,
        row_number() over (partition by order_id order by _loaded_at desc) as _rn
    from {{ source("olist", "orders") }}

)

select
    order_id::varchar(32) as order_id,
    customer_id::varchar(32) as customer_id,
    order_status::varchar(20) as order_status,
    nullif(order_purchase_timestamp, '')::timestamp as order_purchase_timestamp,
    nullif(order_approved_at, '')::timestamp as order_approved_at,
    nullif(order_delivered_carrier_date, '')::timestamp as order_delivered_carrier_date,
    nullif(order_delivered_customer_date, '')::timestamp as order_delivered_customer_date,
    nullif(order_estimated_delivery_date, '')::timestamp as order_estimated_delivery_date,
    _loaded_at
from source
where _rn = 1

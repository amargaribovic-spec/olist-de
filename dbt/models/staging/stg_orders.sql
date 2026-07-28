-- Staging model: light cleanup of the raw orders table.
-- Raw timestamps are stored as text; nullif(...,'') turns empty strings into
-- NULL so the ::timestamp cast doesn't error on missing values.
select
    order_id::varchar(32) as order_id,
    customer_id::varchar(32) as customer_id,
    order_status::varchar(20) as order_status,
    nullif(order_purchase_timestamp, '')::timestamp as order_purchase_timestamp,
    nullif(order_approved_at, '')::timestamp as order_approved_at,
    nullif(order_delivered_carrier_date, '')::timestamp as order_delivered_carrier_date,
    nullif(order_delivered_customer_date, '')::timestamp as order_delivered_customer_date,
    nullif(order_estimated_delivery_date, '')::timestamp as order_estimated_delivery_date
from {{ source("olist", "orders") }}

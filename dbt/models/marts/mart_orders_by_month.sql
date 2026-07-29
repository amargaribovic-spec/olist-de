-- NB06: order volume per calendar month (the seasonality trend).
select
    date_trunc('month', order_purchase_timestamp)::date as order_month,
    count(*) as order_count
from {{ ref('stg_orders') }}
where order_purchase_timestamp is not null
group by 1
order by 1

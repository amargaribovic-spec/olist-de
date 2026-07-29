-- NB06: order volume by day of week (0 = Sunday ... 6 = Saturday).
select
    extract(dow from order_purchase_timestamp)::int as weekday_number,
    trim(to_char(order_purchase_timestamp, 'Day')) as weekday_name,
    count(*) as order_count
from {{ ref('stg_orders') }}
where order_purchase_timestamp is not null
group by 1, 2
order by 1

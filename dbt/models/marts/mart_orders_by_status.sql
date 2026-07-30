-- NB01: order count by status (all statuses, not just delivered).
select
    order_status,
    count(*) as order_count,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as order_pct
from {{ ref('stg_orders') }}
group by order_status
order by order_count desc

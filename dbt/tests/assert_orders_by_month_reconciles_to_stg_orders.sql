-- The monthly breakdown must account for every order that has a purchase date.
with breakdown as (

    select sum(order_count) as n from {{ ref('mart_orders_by_month') }}

),

source as (

    select count(*) as n
    from {{ ref('stg_orders') }}
    where order_purchase_timestamp is not null

)

select
    breakdown.n as breakdown_total,
    source.n as source_total
from breakdown
cross join source
where breakdown.n != source.n

-- Every order must be counted exactly once in the status breakdown.
with breakdown as (

    select sum(order_count) as n from {{ ref('mart_orders_by_status') }}

),

source as (

    select count(*) as n from {{ ref('stg_orders') }}

)

select
    breakdown.n as breakdown_total,
    source.n as source_total
from breakdown
cross join source
where breakdown.n != source.n

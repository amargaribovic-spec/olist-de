-- NB10: total (addressable) demand per customer region, and how much is local vs
-- imported from the Southeast. One row per customer region.
with items as (

    select * from {{ ref('int_order_items_regional') }}
    where customer_region is not null

)

select
    customer_region,
    count(*) as item_count,
    sum(price) as revenue,
    round(100.0 * count(*) filter (where seller_region = 'Southeast') / count(*), 2)
        as from_southeast_pct,
    round(100.0 * count(*) filter (where seller_region = customer_region) / count(*), 2)
        as local_pct
from items
group by customer_region
order by item_count desc

-- NB10: supply-flow matrix — item counts per customer region x seller region,
-- with each cell as a share of that customer region's demand.
with items as (

    select * from {{ ref('int_order_items_regional') }}
    where customer_region is not null and seller_region is not null

)

select
    customer_region,
    seller_region,
    count(*) as item_count,
    round(100.0 * count(*) / sum(count(*)) over (partition by customer_region), 2)
        as pct_of_region_demand
from items
group by customer_region, seller_region
order by customer_region asc, item_count desc

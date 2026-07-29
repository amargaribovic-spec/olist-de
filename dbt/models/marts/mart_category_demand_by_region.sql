-- NB10: product-category demand per customer region, and how much is supplied
-- locally vs imported from the Southeast. One row per (customer_region, category).
with items as (

    select * from {{ ref('int_order_items_regional') }}
    where customer_region is not null

)

select
    customer_region,
    category,
    count(*) as item_count,
    sum(price) as revenue,
    round(100.0 * count(*) filter (where seller_region = 'Southeast') / count(*), 2)
        as from_southeast_pct,
    round(100.0 * count(*) filter (where seller_region = customer_region) / count(*), 2)
        as local_pct
from items
group by customer_region, category
order by customer_region asc, item_count desc

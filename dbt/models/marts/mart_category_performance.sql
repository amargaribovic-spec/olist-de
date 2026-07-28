-- NB02: revenue and volume per product category.
with items as (

    select * from {{ ref('int_order_items_categorized') }}
    where price > 0 and freight_value >= 0

)

select
    category,
    count(*) as items_sold,
    sum(price) as revenue,
    round(avg(price), 2) as avg_price,
    round(avg(freight_value), 2) as avg_freight,
    round(100.0 * avg(freight_value) / nullif(avg(price), 0), 2) as freight_pct,
    round(100.0 * sum(price) / sum(sum(price)) over (), 2) as revenue_pct
from items
group by category
order by revenue desc

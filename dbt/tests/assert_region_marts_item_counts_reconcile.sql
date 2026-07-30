-- The three NB10 region marts all derive from int_order_items_regional, so their
-- per-region item counts must tie out exactly (guards against a dropped join or
-- double-count in any one of them).
with demand as (

    select
        customer_region,
        item_count
    from {{ ref('mart_regional_demand') }}

),

supply as (

    select
        customer_region,
        sum(item_count) as item_count
    from {{ ref('mart_regional_supply_flow') }}
    group by customer_region

),

category as (

    select
        customer_region,
        sum(item_count) as item_count
    from {{ ref('mart_category_demand_by_region') }}
    group by customer_region

)

select
    demand.customer_region,
    demand.item_count as demand_count,
    supply.item_count as supply_count,
    category.item_count as category_count
from demand
inner join supply on demand.customer_region = supply.customer_region
inner join category on demand.customer_region = category.customer_region
where
    demand.item_count != supply.item_count
    or demand.item_count != category.item_count

-- NB05: customer vs seller share per state; imbalance = seller_pct - customer_pct.
with customers as (

    select
        customer_state as state,
        count(*) as customers
    from {{ ref('stg_customers') }}
    group by customer_state

),

sellers as (

    select
        seller_state as state,
        count(*) as sellers
    from {{ ref('stg_sellers') }}
    group by seller_state

),

combined as (

    select
        coalesce(c.state, s.state) as state,
        coalesce(c.customers, 0) as customers,
        coalesce(s.sellers, 0) as sellers
    from customers as c
    full outer join sellers as s on c.state = s.state

)

select
    state,
    customers,
    sellers,
    round(100.0 * customers / sum(customers) over (), 2) as customer_pct,
    round(100.0 * sellers / sum(sellers) over (), 2) as seller_pct,
    round(
        100.0 * sellers / sum(sellers) over ()
        - 100.0 * customers / sum(customers) over (),
        2
    ) as imbalance
from combined
order by customers desc

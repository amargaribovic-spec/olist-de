-- NB05: customer vs seller counts per city (read as a top-N ranking).
with customers as (

    select
        customer_city as city,
        customer_state as state,
        count(*) as customer_count
    from {{ ref('stg_customers') }}
    group by customer_city, customer_state

),

sellers as (

    select
        seller_city as city,
        seller_state as state,
        count(*) as seller_count
    from {{ ref('stg_sellers') }}
    group by seller_city, seller_state

)

select
    coalesce(c.city, s.city) as city,
    coalesce(c.state, s.state) as state,
    coalesce(c.customer_count, 0) as customer_count,
    coalesce(s.seller_count, 0) as seller_count
from customers as c
full outer join sellers as s
    on c.city = s.city and c.state = s.state
order by customer_count desc

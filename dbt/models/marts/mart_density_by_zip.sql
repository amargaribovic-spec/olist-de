-- NB05 (map): customer vs seller density per zip, with coordinates — the data
-- behind the geographic heatmap.
with customers as (

    select
        zip_code_prefix,
        min(latitude) as latitude,
        min(longitude) as longitude,
        count(*) as customer_count
    from {{ ref('int_customer_geo') }}
    where latitude is not null
    group by zip_code_prefix

),

sellers as (

    select
        zip_code_prefix,
        min(latitude) as latitude,
        min(longitude) as longitude,
        count(*) as seller_count
    from {{ ref('int_seller_geo') }}
    where latitude is not null
    group by zip_code_prefix

)

select
    coalesce(c.zip_code_prefix, s.zip_code_prefix) as zip_code_prefix,
    coalesce(c.latitude, s.latitude) as latitude,
    coalesce(c.longitude, s.longitude) as longitude,
    coalesce(c.customer_count, 0) as customer_count,
    coalesce(s.seller_count, 0) as seller_count
from customers as c
full outer join sellers as s on c.zip_code_prefix = s.zip_code_prefix

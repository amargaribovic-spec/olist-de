{{ config(materialized="incremental", unique_key="order_id",
          incremental_strategy="merge", on_schema_change="sync_all_columns") }}
-- NB09: customer<->seller distance per order, with freight, delivery and review.
-- distance_km via the haversine formula; bucket bins match the notebook (0/50/200/500/1000/inf).
-- Incremental: merge new/updated orders (by geo _loaded_at) keyed on order_id.
with geo as (

    select * from {{ ref('int_order_geo') }}
    where
        customer_latitude is not null and seller_latitude is not null
        and _loaded_at > {{ incremental_watermark() }}

),

totals as (

    select
        order_id,
        order_total,
        freight_total
    from {{ ref('int_order_item_totals') }}

),

delivery as (

    select
        order_id,
        days_total
    from {{ ref('int_order_delivery') }}

),

reviews as (

    select
        order_id,
        review_score
    from {{ ref('int_reviews_deduped') }}

),

distances as (

    select
        order_id,
        customer_state,
        seller_state,
        _loaded_at,
        customer_state = seller_state as same_state,
        2 * 6371 * asin(sqrt(
            power(sin(radians(seller_latitude - customer_latitude) / 2), 2)
            + cos(radians(customer_latitude)) * cos(radians(seller_latitude))
            * power(sin(radians(seller_longitude - customer_longitude) / 2), 2)
        )) as distance_km
    from geo

)

select
    d.order_id,
    d.customer_state,
    d.seller_state,
    d.same_state,
    d.distance_km,
    t.order_total,
    t.freight_total,
    dl.days_total as delivery_days,
    r.review_score,
    d._loaded_at,
    round(100.0 * t.freight_total / nullif(t.order_total, 0), 2) as freight_pct,
    case
        when d.distance_km < 50 then '0000-0050'
        when d.distance_km < 200 then '0050-0200'
        when d.distance_km < 500 then '0200-0500'
        when d.distance_km < 1000 then '0500-1000'
        else '1000+'
    end as distance_km_bucket
from distances as d
left join totals as t on d.order_id = t.order_id
left join delivery as dl on d.order_id = dl.order_id
left join reviews as r on d.order_id = r.order_id

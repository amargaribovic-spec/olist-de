{{ config(materialized="incremental", unique_key="order_id",
          incremental_strategy="merge", on_schema_change="sync_all_columns") }}
-- NB08: delivery time / lateness vs review score, one row per delivered+rated order.
-- delivery_days_bucket bins match the notebook's pd.cut (0/5/10/15/20/30/inf).
-- Incremental: merge new/updated orders (by delivery _loaded_at) keyed on order_id.
with delivery as (

    select * from {{ ref('int_order_delivery') }}
    where
        is_valid_timeline
        and _loaded_at > {{ incremental_watermark() }}

),

reviews as (

    select
        order_id,
        review_score
    from {{ ref('int_reviews_deduped') }}

)

select
    d.order_id,
    d.days_total,
    d.days_delay,
    d.is_late,
    r.review_score,
    d._loaded_at,
    case
        when d.days_total < 5 then '00-05'
        when d.days_total < 10 then '05-10'
        when d.days_total < 15 then '10-15'
        when d.days_total < 20 then '15-20'
        when d.days_total < 30 then '20-30'
        else '30+'
    end as delivery_days_bucket
from delivery as d
inner join reviews as r on d.order_id = r.order_id

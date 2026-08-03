{{ config(materialized="incremental", unique_key="order_id",
          incremental_strategy="merge", on_schema_change="sync_all_columns") }}
-- NB11: how long customers take to answer the review survey, one row per order.
-- response_days_bucket bins match the notebook's pd.cut (0/1/2/3/7/inf days).
-- Incremental: merge new/updated orders (by _loaded_at) keyed on order_id.
with reviews as (

    select * from {{ ref('int_reviews_deduped') }}
    where
        review_creation_date is not null and review_answer_timestamp is not null
        and _loaded_at > {{ incremental_watermark() }}

),

delivery as (

    select
        order_id,
        is_late
    from {{ ref('int_order_delivery') }}

),

timed as (

    select
        r.order_id,
        r.review_score,
        r.review_creation_date,
        r.review_answer_timestamp,
        d.is_late,
        r._loaded_at,
        extract(epoch from (r.review_answer_timestamp - r.review_creation_date)) / 3600
            as response_hours,
        extract(epoch from (r.review_answer_timestamp - r.review_creation_date)) / 86400
            as response_days
    from reviews as r
    left join delivery as d on r.order_id = d.order_id

)

select
    order_id,
    review_score,
    review_creation_date,
    review_answer_timestamp,
    is_late,
    response_hours,
    response_days,
    _loaded_at,
    case
        when response_days < 1 then '0-1'
        when response_days < 2 then '1-2'
        when response_days < 3 then '2-3'
        when response_days < 7 then '3-7'
        else '7+'
    end as response_days_bucket
from timed

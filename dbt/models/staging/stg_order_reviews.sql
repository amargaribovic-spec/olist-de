-- Staging model: customer reviews per order.
-- review_id is NOT unique in the source, so we add a surrogate key from
-- (review_id, order_id). Dedup to one-per-order happens later (intermediate).
-- Append-only raw → keep the latest row per (review_id, order_id).
with source as (

    select
        *,
        row_number() over (
            partition by review_id, order_id order by _loaded_at desc
        ) as _rn
    from {{ source("olist", "order_reviews") }}

)

select
    ({{ dbt_utils.generate_surrogate_key(['review_id', 'order_id']) }})::varchar(32)
        as review_sk,
    review_id::varchar(32) as review_id,
    order_id::varchar(32) as order_id,
    nullif(review_score, '')::int as review_score,
    ({{ clean_text('review_comment_title') }})::varchar(100) as review_comment_title,
    ({{ clean_text('review_comment_message') }})::varchar(1000) as review_comment_message,
    nullif(review_creation_date, '')::timestamp as review_creation_date,
    nullif(review_answer_timestamp, '')::timestamp as review_answer_timestamp,
    _loaded_at
from source
where _rn = 1

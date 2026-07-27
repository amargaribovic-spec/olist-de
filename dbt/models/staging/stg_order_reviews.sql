-- Staging model: customer reviews per order.
-- review_id is NOT unique in the source, so we add a surrogate key from
-- (review_id, order_id). Dedup to one-per-order happens later (intermediate).
select
    {{ dbt_utils.generate_surrogate_key(['review_id', 'order_id']) }} as review_sk,
    review_id,
    order_id,
    nullif(review_score, '')::int as review_score,
    {{ clean_text('review_comment_title') }} as review_comment_title,
    {{ clean_text('review_comment_message') }} as review_comment_message,
    nullif(review_creation_date, '')::timestamp as review_creation_date,
    nullif(review_answer_timestamp, '')::timestamp as review_answer_timestamp
from {{ source("olist", "order_reviews") }}

{{ config(materialized="table") }}
-- One review per order — the most recent (review_id is not unique in the source).
with reviews as (

    select * from {{ ref('stg_order_reviews') }}

),

ranked as (

    select
        *,
        row_number() over (
            partition by order_id
            -- review_sk breaks ties deterministically so the picked row never
            -- depends on scan/insert order (reproducible run-to-run).
            order by
                review_creation_date desc, review_answer_timestamp desc,
                review_sk desc
        ) as rn
    from reviews

)

select
    review_sk,
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    _loaded_at
from ranked
where rn = 1

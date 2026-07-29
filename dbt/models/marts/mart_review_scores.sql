-- NB07: review-score distribution for delivered orders, with comment rate per score.
with reviews as (

    select r.*
    from {{ ref('int_reviews_deduped') }} as r
    inner join {{ ref('int_order_delivery') }} as d on r.order_id = d.order_id

)

select
    review_score,
    count(*) as review_count,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as review_pct,
    count(review_comment_message) as with_comment,
    round(100.0 * count(review_comment_message) / count(*), 2) as comment_rate
from reviews
where review_score is not null
group by review_score
order by review_score

{{ config(materialized="table") }}
-- Order items + product category (English, else Portuguese, else 'uncategorized').
with items as (

    select * from {{ ref('stg_order_items') }}

),

products as (

    select * from {{ ref('stg_products') }}

),

translation as (

    select * from {{ ref('stg_product_category_translation') }}

)

select
    items.order_item_sk,
    items.order_id,
    items.product_id,
    items.seller_id,
    items.price,
    items.freight_value,
    coalesce(
        translation.product_category_name_english,
        products.product_category_name,
        'uncategorized'
    ) as category
from items
left join products on items.product_id = products.product_id
left join translation
    on products.product_category_name = translation.product_category_name

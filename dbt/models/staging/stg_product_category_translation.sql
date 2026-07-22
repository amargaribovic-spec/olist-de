-- Staging model: Portuguese -> English product category names (lookup table).
select product_category_name, product_category_name_english
from {{ source("olist", "product_category_translation") }}

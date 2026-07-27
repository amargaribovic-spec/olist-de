-- Staging model: product catalogue. Casts numeric dimensions.
-- Source keeps the original misspelling "lenght"; renamed to correct "length" here.
select
    product_id::varchar as product_id,
    nullif(product_name_lenght, '')::int as product_name_length,
    nullif(product_description_lenght, '')::int as product_description_length,
    nullif(product_photos_qty, '')::int as product_photos_qty,
    nullif(product_weight_g, '')::numeric as product_weight_g,
    nullif(product_length_cm, '')::numeric as product_length_cm,
    nullif(product_height_cm, '')::numeric as product_height_cm,
    nullif(product_width_cm, '')::numeric as product_width_cm,
    ({{ clean_text('product_category_name') }})::varchar as product_category_name
from {{ source("olist", "products") }}

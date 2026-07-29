{{ config(materialized="table") }}
-- Sellers + lat/lng from their zip prefix.
with sellers as (

    select * from {{ ref('stg_sellers') }}

),

geo as (

    select * from {{ ref('int_geolocation_by_zip') }}

)

select
    sellers.seller_id,
    sellers.zip_code_prefix,
    sellers.seller_city,
    sellers.seller_state,
    geo.latitude,
    geo.longitude
from sellers
left join geo on sellers.zip_code_prefix = geo.zip_code_prefix

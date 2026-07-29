{{ config(materialized="table") }}
-- Customers + lat/lng from their zip prefix.
with customers as (

    select * from {{ ref('stg_customers') }}

),

geo as (

    select * from {{ ref('int_geolocation_by_zip') }}

)

select
    customers.customer_id,
    customers.customer_unique_id,
    customers.zip_code_prefix,
    customers.customer_city,
    customers.customer_state,
    geo.latitude,
    geo.longitude
from customers
left join geo on customers.zip_code_prefix = geo.zip_code_prefix

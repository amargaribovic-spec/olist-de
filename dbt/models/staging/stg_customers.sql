-- Staging model: light cleanup of the raw customers table.
-- Materialized as a view (configured in dbt_project.yml).

select
    customer_id,
    customer_unique_id,
    geolocation_zip_code_prefix as zip_code_prefix,
    customer_city,
    customer_state
from raw.customers

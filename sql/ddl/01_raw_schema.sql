-- Raw landing schema: source CSVs loaded as-is (all data columns TEXT, no
-- constraints). Typing, cleaning and constraints are handled downstream in dbt.
--
-- Raw is an APPEND-ONLY landing zone: every row carries a _loaded_at stamp so
-- downstream incremental models can process only what's new, and a load ledger
-- records which files have been loaded (making incremental loads idempotent).

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id                      TEXT,
    customer_id                   TEXT,
    order_status                  TEXT,
    order_purchase_timestamp      TEXT,
    order_approved_at             TEXT,
    order_delivered_carrier_date  TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT,
    _loaded_at                    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id            TEXT,
    order_item_id       TEXT,
    product_id          TEXT,
    seller_id           TEXT,
    shipping_limit_date TEXT,
    price               TEXT,
    freight_value       TEXT,
    _loaded_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.order_payments (
    order_id             TEXT,
    payment_sequential   TEXT,
    payment_type         TEXT,
    payment_installments TEXT,
    payment_value        TEXT,
    _loaded_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.order_reviews (
    review_id               TEXT,
    order_id                TEXT,
    review_score            TEXT,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TEXT,
    review_answer_timestamp TEXT,
    _loaded_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- zip column named geolocation_zip_code_prefix to match the geolocation join key
CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id                 TEXT,
    customer_unique_id          TEXT,
    geolocation_zip_code_prefix TEXT,
    customer_city               TEXT,
    customer_state              TEXT,
    _loaded_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id                   TEXT,
    geolocation_zip_code_prefix TEXT,
    seller_city                 TEXT,
    seller_state                TEXT,
    _loaded_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- column names keep the source's original misspelling ("lenght")
CREATE TABLE IF NOT EXISTS raw.products (
    product_id                 TEXT,
    product_category_name      TEXT,
    product_name_lenght        TEXT,
    product_description_lenght TEXT,
    product_photos_qty         TEXT,
    product_weight_g           TEXT,
    product_length_cm          TEXT,
    product_height_cm          TEXT,
    product_width_cm           TEXT,
    _loaded_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.product_category_translation (
    product_category_name         TEXT,
    product_category_name_english TEXT,
    _loaded_at                    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.geolocation (
    geolocation_zip_code_prefix TEXT,
    geolocation_lat             TEXT,
    geolocation_lng             TEXT,
    geolocation_city            TEXT,
    geolocation_state           TEXT,
    _loaded_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Load ledger: one row per file loaded. The sha256 makes re-loading the same
-- file a no-op, so incremental (append) loads are safe to re-run.
CREATE TABLE IF NOT EXISTS raw._load_ledger (
    id           BIGSERIAL PRIMARY KEY,
    source_file  TEXT NOT NULL,
    table_name   TEXT NOT NULL,
    row_count    INTEGER NOT NULL,
    file_sha256  TEXT NOT NULL,
    loaded_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

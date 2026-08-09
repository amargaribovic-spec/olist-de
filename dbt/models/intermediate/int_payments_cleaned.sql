-- Payment rows cleaned to the analysis spec (NB04, "cleaning" step):
--   - drop 'not_defined'   (carries no payment info; value is always 0)
--   - drop invalid installments per type: credit_card must have >= 1;
--     boleto / voucher / debit_card must not exceed 1.
--
-- raw stays append-only and keeps every row; payment validity is enforced HERE,
-- once, so every downstream payment model reuses the same cleaned set instead of
-- each re-deciding what a valid payment is.
with payments as (

    select * from {{ ref('stg_order_payments') }}

)

select *
from payments
where
    payment_type != 'not_defined'
    and not (payment_type = 'credit_card' and payment_installments < 1)
    and not (payment_type in ('boleto', 'voucher', 'debit_card') and payment_installments > 1)

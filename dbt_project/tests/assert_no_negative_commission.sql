-- tests/assert_no_negative_commission.sql
-- Custom singular test: commission_earned must never be negative.
-- A negative value would indicate a data error in rate or amount fields.
-- This test PASSES when the query returns 0 rows.

select
    payment_id,
    amount_paid,
    commission_earned
from {{ ref('fct_payments') }}
where commission_earned < 0

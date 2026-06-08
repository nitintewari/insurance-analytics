-- stg_payments.sql
-- Cleans payment records. Adds days-to-pay, failure flags, and period keys.

with source as (
    select * from {{ source('raw', 'payments') }}
),

renamed as (
    select
        payment_id,
        policy_id,
        member_id,
        cast(due_date as date)                  as due_date,
        cast(paid_date as date)                 as paid_date,
        cast(amount_due as numeric)             as amount_due,
        cast(amount_paid as numeric)            as amount_paid,
        lower(payment_status)                   as payment_status,
        lower(payment_method)                   as payment_method,
        carrier,
        plan_type,

        -- derived
        case
            when lower(payment_status) = 'failed' then true
            else false
        end                                     as is_failed,

        case
            when lower(payment_status) = 'paid_late' then true
            else false
        end                                     as is_late,

        case
            when paid_date is not null
            then date_diff(cast(paid_date as date), cast(due_date as date), day)
            else null
        end                                     as days_to_pay,

        cast(amount_due - amount_paid as numeric)
                                                as payment_gap,

        extract(year  from cast(due_date as date))   as due_year,
        extract(month from cast(due_date as date))   as due_month,
        format_date('%Y-%m', cast(due_date as date)) as due_period

    from source
)

select * from renamed

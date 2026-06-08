-- stg_cancellations.sql
-- Cleans cancellation records. Adds churn category and early-cancel flag.

with source as (
    select * from {{ source('raw', 'cancellations') }}
),

renamed as (
    select
        cancellation_id,
        policy_id,
        member_id,
        agent_id,
        cast(cancellation_date as date)         as cancellation_date,
        lower(cancellation_reason)              as cancellation_reason,
        cast(months_active as int64)            as months_active,
        cast(lifetime_value as numeric)         as lifetime_value,
        carrier,
        plan_type,
        cast(was_payment_failure as bool)       as was_payment_failure,

        -- derived
        case
            when lower(cancellation_reason) = 'non_payment'    then 'involuntary'
            when lower(cancellation_reason) = 'deceased'       then 'involuntary'
            else 'voluntary'
        end                                     as churn_type,

        -- early cancellation = within first 3 months
        case
            when cast(months_active as int64) <= 3 then true
            else false
        end                                     as is_early_cancel,

        extract(year  from cast(cancellation_date as date))     as cancel_year,
        extract(month from cast(cancellation_date as date))     as cancel_month,
        format_date('%Y-%m', cast(cancellation_date as date))   as cancel_period

    from source
)

select * from renamed

-- stg_policies.sql
-- Standardizes policy records. Adds eligibility window flags and annualized revenue.

with source as (
    select * from {{ source('raw', 'policies') }}
),

renamed as (
    select
        policy_id,
        member_id,
        agent_id,
        carrier,
        plan_type,
        cast(effective_date as date)            as effective_date,
        cast(expiry_date as date)               as expiry_date,
        cast(monthly_premium as numeric)        as monthly_premium,
        cast(annual_premium as numeric)         as annual_premium,
        cast(commission_rate as numeric)        as commission_rate,
        cast(monthly_commission as numeric)     as monthly_commission,
        lower(status)                           as policy_status,
        cast(term_months as int64)              as term_months,

        -- derived
        cast(monthly_commission * 12 as numeric)
                                                as annual_commission,

        -- is the policy currently within its eligibility window?
        case
            when lower(status) = 'active'
             and current_date() between cast(effective_date as date)
                                    and cast(expiry_date as date)
            then true
            else false
        end                                     as is_currently_eligible,

        date_diff(
            cast(expiry_date as date),
            cast(effective_date as date),
            day
        )                                       as policy_duration_days

    from source
)

select * from renamed

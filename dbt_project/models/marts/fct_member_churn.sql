-- fct_member_churn.sql
-- Member churn / cancellation fact table.
-- One row per cancelled policy. Powers the churn funnel and retention dashboards.
-- Key business question: who is churning, why, and which agents/plans have highest churn?

with cancellations as (
    select * from {{ ref('stg_cancellations') }}
),

policies as (
    select
        policy_id,
        effective_date,
        expiry_date,
        monthly_premium,
        annual_premium,
        term_months,
        policy_status
    from {{ ref('stg_policies') }}
),

members as (
    select
        member_id,
        full_name,
        state,
        age_bucket,
        plan_category,
        enrollment_date
    from {{ ref('stg_members') }}
),

agents as (
    select
        agent_id,
        agent_name,
        agency_name,
        tier
    from {{ ref('stg_agents') }}
),

-- get last successful payment before cancellation
last_payment as (
    select
        p.policy_id,
        max(p.paid_date)    as last_paid_date
    from {{ ref('stg_payments') }} p
    where p.payment_status != 'failed'
    group by p.policy_id
),

joined as (
    select
        c.cancellation_id,
        c.policy_id,
        c.member_id,
        c.agent_id,
        agt.agent_name,
        agt.agency_name,
        agt.tier                                as agent_tier,
        mem.full_name                           as member_name,
        mem.state,
        mem.age_bucket,
        mem.plan_category,
        c.cancellation_date,
        c.cancel_period,
        c.cancel_year,
        c.cancel_month,
        c.cancellation_reason,
        c.churn_type,
        c.is_early_cancel,
        c.months_active,
        c.lifetime_value,
        c.was_payment_failure,
        c.carrier,
        c.plan_type,
        pol.monthly_premium,
        pol.effective_date                      as policy_start_date,
        lp.last_paid_date,

        -- months between last payment and cancellation (gap = likely non_payment)
        case
            when lp.last_paid_date is not null
            then date_diff(c.cancellation_date, lp.last_paid_date, month)
            else null
        end                                     as months_since_last_payment,

        -- annualized revenue lost due to this churn
        round(pol.monthly_premium * 12, 2)      as annualized_revenue_lost

    from cancellations c
    left join policies pol   using (policy_id)
    left join members  mem   using (member_id)
    left join agents   agt   using (agent_id)
    left join last_payment lp using (policy_id)
)

select * from joined

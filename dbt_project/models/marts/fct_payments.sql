-- fct_payments.sql
-- Core payments fact table. One row per monthly premium payment event.
-- Joins to agent and member context for full analytical coverage.
-- Drives revenue, collection rate, and payment failure KPIs.

with payments as (
    select * from {{ ref('stg_payments') }}
),

policies as (
    select
        policy_id,
        commission_rate,
        monthly_commission,
        term_months,
        policy_status
    from {{ ref('stg_policies') }}
),

members as (
    select
        member_id,
        agent_id,
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

joined as (
    select
        pay.payment_id,
        pay.policy_id,
        pay.member_id,
        mem.agent_id,
        agt.agent_name,
        agt.agency_name,
        agt.tier                                as agent_tier,
        pay.due_date,
        pay.paid_date,
        pay.due_year,
        pay.due_month,
        pay.due_period,
        pay.amount_due,
        pay.amount_paid,
        pay.payment_gap,
        pay.payment_status,
        pay.payment_method,
        pay.is_failed,
        pay.is_late,
        pay.days_to_pay,
        pay.carrier,
        pay.plan_type,
        mem.plan_category,
        mem.state,
        mem.age_bucket,

        -- commission earned only on successful payments
        case
            when pay.payment_status != 'failed'
            then round(pay.amount_paid * pol.commission_rate, 2)
            else 0
        end                                     as commission_earned,

        -- rolling revenue flag
        case
            when pay.payment_status = 'failed' then 'uncollected'
            when pay.is_late                   then 'collected_late'
            else 'collected_on_time'
        end                                     as collection_status

    from payments pay
    left join policies pol using (policy_id)
    left join members  mem using (member_id)
    left join agents   agt using (agent_id)
)

select * from joined

-- agent_commission_summary.sql
-- Monthly agent commission reconciliation report.
-- One row per agent per month. Answers: what did each agent earn, collect, and lose to churn?
-- This is the model that maps directly to NCD's commissions workflow.

with monthly_payments as (
    select
        agent_id,
        agent_name,
        agency_name,
        agent_tier,
        due_period,
        due_year,
        due_month,
        carrier,

        count(payment_id)                           as total_payments_due,
        countif(payment_status = 'paid')            as paid_on_time,
        countif(payment_status = 'paid_late')       as paid_late,
        countif(payment_status = 'failed')          as payments_failed,

        sum(amount_due)                             as total_amount_due,
        sum(amount_paid)                            as total_amount_collected,
        sum(payment_gap)                            as total_uncollected,
        sum(commission_earned)                      as total_commission_earned,

        count(distinct member_id)                   as active_members_billed

    from {{ ref('fct_payments') }}
    group by
        agent_id, agent_name, agency_name, agent_tier,
        due_period, due_year, due_month, carrier
),

monthly_churn as (
    select
        agent_id,
        cancel_period,
        count(*)                                    as members_churned,
        sum(annualized_revenue_lost)                as revenue_lost_to_churn,
        countif(churn_type = 'involuntary')         as involuntary_churns
    from {{ ref('fct_member_churn') }}
    group by agent_id, cancel_period
)

select
    mp.agent_id,
    mp.agent_name,
    mp.agency_name,
    mp.agent_tier,
    mp.due_period                               as period,
    mp.due_year                                 as year,
    mp.due_month                                as month,
    mp.carrier,

    mp.total_payments_due,
    mp.paid_on_time,
    mp.paid_late,
    mp.payments_failed,
    mp.active_members_billed,

    mp.total_amount_due,
    mp.total_amount_collected,
    mp.total_uncollected,
    mp.total_commission_earned,

    coalesce(mc.members_churned, 0)             as members_churned,
    coalesce(mc.involuntary_churns, 0)          as involuntary_churns,
    coalesce(mc.revenue_lost_to_churn, 0)       as revenue_lost_to_churn,

    -- collection rate
    round(
        safe_divide(mp.total_amount_collected, mp.total_amount_due) * 100,
    2)                                          as collection_rate_pct,

    -- payment failure rate
    round(
        safe_divide(mp.payments_failed, mp.total_payments_due) * 100,
    2)                                          as failure_rate_pct

from monthly_payments mp
left join monthly_churn mc
    on mp.agent_id = mc.agent_id
   and mp.due_period = mc.cancel_period

order by mp.due_period desc, mp.total_commission_earned desc

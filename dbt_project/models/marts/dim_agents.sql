-- dim_agents.sql
-- Agent dimension table. One row per agent with performance summary metrics.
-- Used as a lookup in all agent-level reporting.

with agents as (
    select * from {{ ref('stg_agents') }}
),

policy_summary as (
    select
        agent_id,
        count(*)                                    as total_policies,
        countif(policy_status = 'active')           as active_policies,
        countif(policy_status = 'cancelled')        as cancelled_policies,
        sum(monthly_premium)                        as total_monthly_premium,
        sum(monthly_commission)                     as total_monthly_commission,
        sum(annual_commission)                      as total_annual_commission
    from {{ ref('stg_policies') }}
    group by agent_id
),

member_summary as (
    select
        agent_id,
        count(distinct member_id)                   as total_members
    from {{ ref('stg_members') }}
    group by agent_id
),

cancellation_summary as (
    select
        agent_id,
        count(*)                                    as total_cancellations,
        countif(churn_type = 'involuntary')         as involuntary_cancellations
    from {{ ref('stg_cancellations') }}
    group by agent_id
)

select
    a.agent_id,
    a.agent_name,
    a.agency_name,
    a.state,
    a.email,
    a.hire_date,
    a.is_active,
    a.tier,
    a.tier_rank,
    a.months_tenure,

    coalesce(m.total_members, 0)                    as total_members,
    coalesce(p.total_policies, 0)                   as total_policies,
    coalesce(p.active_policies, 0)                  as active_policies,
    coalesce(p.cancelled_policies, 0)               as cancelled_policies,
    coalesce(p.total_monthly_premium, 0)            as total_monthly_premium,
    coalesce(p.total_monthly_commission, 0)         as total_monthly_commission,
    coalesce(p.total_annual_commission, 0)          as total_annual_commission,
    coalesce(c.total_cancellations, 0)              as total_cancellations,
    coalesce(c.involuntary_cancellations, 0)        as involuntary_cancellations,

    -- cancellation rate
    case
        when coalesce(p.total_policies, 0) = 0 then null
        else round(
            coalesce(p.cancelled_policies, 0) * 100.0 / p.total_policies,
        2)
    end                                             as cancellation_rate_pct

from agents a
left join policy_summary p   using (agent_id)
left join member_summary m   using (agent_id)
left join cancellation_summary c using (agent_id)

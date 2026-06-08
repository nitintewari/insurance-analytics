-- ============================================================
-- NCD Insurance Analytics — Core Business SQL Queries
-- Warehouse: BigQuery  |  Layer: marts
-- Each query answers a real business question from the JD.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- Q1. Monthly Revenue & Collection Rate Trend
-- Business: Are we collecting what we're owed, month over month?
-- ────────────────────────────────────────────────────────────
select
    due_period,
    due_year,
    due_month,
    sum(amount_due)                                     as total_billed,
    sum(amount_paid)                                    as total_collected,
    sum(payment_gap)                                    as total_uncollected,
    countif(is_failed)                                  as failed_payments,
    round(sum(amount_paid) / nullif(sum(amount_due), 0) * 100, 2)
                                                        as collection_rate_pct,
    round(countif(is_failed) * 100.0 / count(*), 2)    as failure_rate_pct
from `your_project.ncd_dev_marts.fct_payments`
group by due_period, due_year, due_month
order by due_period;


-- ────────────────────────────────────────────────────────────
-- Q2. Top 20 Agents by Commission Earned (YTD)
-- Business: Who are our best-performing agents this year?
-- ────────────────────────────────────────────────────────────
select
    agent_id,
    agent_name,
    agency_name,
    agent_tier,
    sum(total_commission_earned)                        as ytd_commission,
    sum(active_members_billed)                          as avg_active_members,
    round(avg(collection_rate_pct), 2)                  as avg_collection_rate,
    round(avg(failure_rate_pct), 2)                     as avg_failure_rate,
    sum(members_churned)                                as total_churns
from `your_project.ncd_dev_marts.agent_commission_summary`
where year = extract(year from current_date())
group by agent_id, agent_name, agency_name, agent_tier
order by ytd_commission desc
limit 20;


-- ────────────────────────────────────────────────────────────
-- Q3. Member Churn by Reason & Plan Type
-- Business: Why are members leaving, and which plans have highest churn?
-- ────────────────────────────────────────────────────────────
select
    plan_type,
    cancellation_reason,
    churn_type,
    count(*)                                            as total_cancellations,
    round(avg(months_active), 1)                        as avg_months_active,
    sum(lifetime_value)                                 as total_ltv_lost,
    sum(annualized_revenue_lost)                        as annualized_revenue_lost,
    countif(is_early_cancel)                            as early_cancels,
    round(countif(is_early_cancel) * 100.0 / count(*), 2)
                                                        as early_cancel_rate_pct
from `your_project.ncd_dev_marts.fct_member_churn`
group by plan_type, cancellation_reason, churn_type
order by total_cancellations desc;


-- ────────────────────────────────────────────────────────────
-- Q4. Eligibility Gap Detection
-- Business: Which members have a policy gap (cancelled but no replacement)?
-- This is a key operational query — mirrors carrier file reconciliation.
-- ────────────────────────────────────────────────────────────
with active_members as (
    select distinct member_id
    from `your_project.ncd_dev_marts.fct_payments`
    where payment_status != 'failed'
      and due_date >= date_sub(current_date(), interval 60 day)
),

cancelled_members as (
    select
        member_id,
        max(cancellation_date)      as last_cancel_date,
        string_agg(cancellation_reason, ', ') as reasons
    from `your_project.ncd_dev_marts.fct_member_churn`
    group by member_id
)

select
    c.member_id,
    c.last_cancel_date,
    c.reasons                                           as cancellation_reasons,
    date_diff(current_date(), c.last_cancel_date, day)  as days_since_cancel,
    case
        when a.member_id is not null then 'has_active_policy'
        else 'eligibility_gap'
    end                                                 as eligibility_status
from cancelled_members c
left join active_members a using (member_id)
where a.member_id is null  -- no active payment in last 60 days
order by c.last_cancel_date desc;


-- ────────────────────────────────────────────────────────────
-- Q5. Payment Failure Cohort — Non-Payment Churn Risk
-- Business: Which currently active members show signs of upcoming churn
--           based on recent late/failed payments?
-- ────────────────────────────────────────────────────────────
with recent_payment_behavior as (
    select
        member_id,
        agent_id,
        agent_name,
        plan_type,
        state,
        count(payment_id)                               as payments_last_90d,
        countif(is_failed)                              as failures_last_90d,
        countif(is_late)                                as late_last_90d,
        max(due_date)                                   as most_recent_due_date
    from `your_project.ncd_dev_marts.fct_payments`
    where due_date >= date_sub(current_date(), interval 90 day)
    group by member_id, agent_id, agent_name, plan_type, state
)

select
    member_id,
    agent_id,
    agent_name,
    plan_type,
    state,
    payments_last_90d,
    failures_last_90d,
    late_last_90d,
    most_recent_due_date,
    round(failures_last_90d * 100.0 / nullif(payments_last_90d, 0), 1)
                                                        as failure_rate_pct,
    case
        when failures_last_90d >= 2                     then 'high_risk'
        when failures_last_90d = 1 or late_last_90d >= 2 then 'medium_risk'
        else 'low_risk'
    end                                                 as churn_risk_tier
from recent_payment_behavior
where failures_last_90d > 0 or late_last_90d >= 2
order by failures_last_90d desc, late_last_90d desc;


-- ────────────────────────────────────────────────────────────
-- Q6. Carrier Revenue Breakdown
-- Business: Which carrier (MetLife / VSP / Zurich) drives the most revenue?
-- ────────────────────────────────────────────────────────────
select
    carrier,
    due_year,
    count(distinct member_id)                           as members,
    sum(amount_due)                                     as total_billed,
    sum(amount_paid)                                    as total_collected,
    sum(commission_earned)                              as total_commissions,
    round(sum(amount_paid) / nullif(sum(amount_due), 0) * 100, 2)
                                                        as collection_rate_pct
from `your_project.ncd_dev_marts.fct_payments`
group by carrier, due_year
order by due_year desc, total_collected desc;

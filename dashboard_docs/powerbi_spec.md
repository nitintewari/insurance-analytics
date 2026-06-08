# Dashboard Specification — NCD Insurance Operations
# Power BI Build Guide
# Source: ncd_dev_marts schema in BigQuery

## Page 1 — Executive KPIs

### Visuals
1. **KPI Cards (top row)**
   - Total Active Members  → count of members where policy_status = 'active'
   - Monthly Revenue Billed → sum(amount_due) for current month
   - Monthly Revenue Collected → sum(amount_paid) for current month
   - Collection Rate → billed/collected %
   - YTD Commissions Paid → sum(commission_earned) YTD

2. **Line Chart — Collection Rate Trend (24 months)**
   - X: due_period  |  Y: collection_rate_pct
   - Source: fct_payments aggregated by due_period

3. **Stacked Bar — Revenue by Carrier per Month**
   - X: due_period  |  Y: amount_collected  |  Legend: carrier
   - Source: fct_payments

4. **Donut — Plan Type Revenue Mix**
   - Source: fct_payments grouped by plan_type, sum(amount_paid)

---

## Page 2 — Agent Performance

### Visuals
1. **Bar Chart — Top 20 Agents by YTD Commission**
   - Source: agent_commission_summary, filtered to current year
   - Color by agent_tier

2. **Scatter — Agent Tier vs Collection Rate**
   - X: agent_tier_rank  |  Y: avg collection_rate_pct  |  Size: active_members_billed
   - Source: agent_commission_summary

3. **Table — Agent Scorecard**
   Columns: agent_name | agency_name | tier | active_members | ytd_commission
            | collection_rate | failure_rate | total_churns
   Conditional formatting: red if failure_rate > 5%, green if collection_rate > 95%

4. **KPI Cards**
   - Total agents active
   - Avg commission per agent
   - % agents with >95% collection rate

---

## Page 3 — Member Churn Funnel

### Visuals
1. **Waterfall — Churn by Reason**
   - Source: fct_member_churn grouped by cancellation_reason, count(*)
   - Order: non_payment → member_request → employer_change → moved → plan_upgrade → deceased

2. **Bar Chart — Churn Rate by Plan Type**
   - Source: join fct_member_churn and stg_policies, churn count / total policies per plan

3. **Line Chart — Monthly Churn Volume**
   - X: cancel_period  |  Y: count(*) total cancellations
   - Split lines: voluntary vs involuntary

4. **Map — Churn Rate by State**
   - Source: fct_member_churn grouped by state, churn count

5. **Table — Early Cancel Watchlist**
   - Members who cancelled within 3 months (is_early_cancel = true)
   - Columns: member_name | plan_type | agent_name | months_active | reason | ltv_lost

---

## Filters / Slicers (all pages)
- Date range (due_period / cancel_period)
- Carrier (MetLife, VSP, Zurich)
- Plan type
- Agent tier
- State

## Refresh Schedule
- Daily refresh via BigQuery DirectQuery or scheduled import
- Alert if data is >24 hours stale

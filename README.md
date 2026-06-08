# Insurance Operations Analytics

An end-to-end analytics pipeline simulating the operational data environment of a insurance provider. Built with **BigQuery**, **dbt**, and **Power BI**, this project models the core data workflows an analyst would own at a Insurance company : member eligibility, agent commissions, payment collection, and member churn.

---

## Business Questions Answered

| Dashboard Page | Key Questions |
|---|---|
| **Executive KPIs** | What is our monthly collection rate? How much revenue did we collect vs. bill? Which carrier drives the most premium? |
| **Agent Performance** | Who are our top 20 agents by commission? Which agents have high churn rates on their book? Which tier generates the best collection rates? |
| **Member Churn Funnel** | Why are members cancelling? Which plans churn fastest? How much annualized revenue is lost to non-payment vs. voluntary churn? |

---

## Data Model

Five source tables → staging layer (cleaning + typing) → marts layer (business-ready analytics).

```
RAW SEEDS (simulates Fivetran-fed sources)
├── agents.csv          80 agents across 10 states
├── members.csv         5,000 enrolled members
├── policies.csv        5,000 policies (active, cancelled, expired)
├── payments.csv        ~48,000 monthly premium payment events
└── cancellations.csv   ~1,000 cancellation records

STAGING LAYER (views — cleaning, casting, derived fields)
├── stg_agents
├── stg_members
├── stg_policies
├── stg_payments
└── stg_cancellations

MARTS LAYER (tables — business-ready, join-ready)
├── dim_agents                  Agent dimension with performance metrics
├── fct_payments                Core payment fact (revenue, commissions, failures)
├── fct_member_churn            Cancellation fact (churn reason, LTV lost, risk flags)
└── agent_commission_summary    Monthly agent × carrier commission reconciliation
```

---

## Key Metrics Defined

| Metric | Definition |
|---|---|
| **Collection Rate** | `sum(amount_paid) / sum(amount_due)` — % of billed premium actually collected |
| **Failure Rate** | `count(failed payments) / count(total payments)` |
| **Involuntary Churn** | Cancellations driven by non-payment or death (vs. member-initiated) |
| **Early Cancel** | Policy cancelled within first 3 months of effective date |
| **Churn Risk Tier** | `high` = 2+ payment failures in 90 days; `medium` = 1 failure or 2+ late |
| **Agent Commission** | `amount_paid × commission_rate` — only earned on successful collections |

---

## Tech Stack

| Layer | Tool |
|---|---|
| Data generation | Python (Faker, Pandas) |
| Warehouse | Google BigQuery (free tier) |
| Transformation | dbt Core |
| BI / Reporting | Power BI (or Looker Studio) |
| Version control | Git / GitHub |

---

## Project Structure

```
ncd_insurance_analytics/
├── data_generation/
│   └── generate_data.py          Synthetic data generator (5 tables, ~60K rows)
├── dbt_project/
│   ├── dbt_project.yml
│   ├── profiles.yml               BigQuery connection config
│   ├── models/
│   │   ├── staging/
│   │   │   ├── sources.yml        Source definitions + freshness tests
│   │   │   ├── stg_agents.sql
│   │   │   ├── stg_members.sql
│   │   │   ├── stg_policies.sql
│   │   │   ├── stg_payments.sql
│   │   │   └── stg_cancellations.sql
│   │   └── marts/
│   │       ├── schema.yml         Column docs + dbt tests for all marts
│   │       ├── dim_agents.sql
│   │       ├── fct_payments.sql
│   │       ├── fct_member_churn.sql
│   │       └── agent_commission_summary.sql
│   └── tests/
│       └── assert_no_negative_commission.sql
└── sql_analysis/
    └── core_business_queries.sql  6 standalone business queries
```

---

## How to Run Locally

### 1. Generate synthetic data
```bash
pip install faker pandas numpy
python data_generation/generate_data.py
# → writes 5 CSV files to dbt_project/seeds/
```

### 2. Set up BigQuery
- Create a free GCP project at console.cloud.google.com
- Enable the BigQuery API
- Run: `gcloud auth application-default login`

### 3. Configure dbt
```bash
pip install dbt-bigquery
# Copy profiles.yml to ~/.dbt/profiles.yml
# Replace <your-gcp-project-id> with your actual project ID
```

### 4. Run the pipeline
```bash
cd dbt_project
dbt deps          # install packages
dbt seed          # load CSVs into BigQuery raw schema
dbt run           # build all staging + mart models
dbt test          # run all data quality tests
dbt docs generate && dbt docs serve   # view lineage + docs
```

---

## Data Quality Tests

dbt tests are defined in `sources.yml` and `schema.yml`:

- **Uniqueness**: primary keys on all 5 source tables and all 4 mart models
- **Not-null**: all foreign keys and business-critical fields
- **Referential integrity**: `member.agent_id → agents`, `policy.member_id → members`, etc.
- **Accepted values**: `status`, `tier`, `payment_status`, `churn_type`, `cancellation_reason`
- **Range checks**: `collection_rate_pct` between 0–100, `commission_earned` ≥ 0

Custom test: `assert_no_negative_commission.sql` — validates no payment row has negative commission.

---

## Dashboard Pages (Power BI)

**Page 1 — Executive KPIs**
- Total active members, monthly revenue billed vs. collected, collection rate trend
- Carrier revenue split (MetLife / VSP / Zurich)
- YTD commissions paid

**Page 2 — Agent Performance**
- Top agents by commission (bar chart)
- Agent tier vs. collection rate scatter
- High-churn agents flagged in red

**Page 3 — Member Churn Funnel**
- Churn by reason (waterfall: voluntary vs. involuntary)
- Churn rate by plan type
- Early cancel % trend
- Churn risk heatmap by state

---

## What I Would Do With Real Data

1. **Connect Fivetran** feeds from the CRM and billing system instead of seed CSVs
2. **Add incremental dbt models** for payments to avoid full-table scans on 12M+ row history
3. **Set up dbt Cloud** with scheduled runs and Slack alerting on test failures
4. **Build a data freshness monitor** — alert if payments table hasn't updated within 24 hours
5. **Row-level security** in Power BI so each agent sees only their own book of business

---

*Built by Nitin Tewari — targeting Data Analyst role | [LinkedIn](https://linkedin.com/in/nitintewari39) | [GitHub](https://github.com/nitintewari39)*

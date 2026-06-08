"""
NCD Insurance Analytics — Synthetic Data Generator
Generates realistic dental/vision insurance operational data across 5 tables:
  - agents
  - members
  - policies
  - payments
  - cancellations
"""

import pandas as pd
import numpy as np
from faker import Faker
from datetime import date, timedelta
import random
import os

fake = Faker("en_US")
Faker.seed(42)
random.seed(42)
np.random.seed(42)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "../seeds")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── Config ────────────────────────────────────────────────────────────────────
N_AGENTS      = 80
N_MEMBERS     = 5000
START_DATE    = date(2023, 1, 1)
END_DATE      = date(2024, 12, 31)

CARRIERS      = ["MetLife", "VSP", "Zurich"]
PLAN_TYPES    = ["Dental Basic", "Dental Premium", "Vision Basic", "Vision Premium", "Dental+Vision Bundle"]
STATES        = ["IN", "OH", "IL", "MI", "KY", "TN", "GA", "FL", "TX", "CA"]
CANCEL_REASONS= ["non_payment", "member_request", "employer_change", "moved_out_of_area", "plan_upgrade", "deceased"]
PAYMENT_METHODS = ["credit_card", "ach", "check"]

PLAN_PREMIUMS = {
    "Dental Basic":           29.99,
    "Dental Premium":         54.99,
    "Vision Basic":           19.99,
    "Vision Premium":         34.99,
    "Dental+Vision Bundle":   74.99,
}

COMMISSION_RATES = {
    "Dental Basic":           0.18,
    "Dental Premium":         0.22,
    "Vision Basic":           0.16,
    "Vision Premium":         0.20,
    "Dental+Vision Bundle":   0.25,
}

def rand_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

def date_range_months(start, months):
    m = start.month - 1 + months
    year = start.year + m // 12
    month = m % 12 + 1
    return date(year, month, 1)

# ── 1. Agents ─────────────────────────────────────────────────────────────────
print("Generating agents...")
agents = []
for i in range(1, N_AGENTS + 1):
    hire_date = rand_date(date(2018, 1, 1), date(2023, 6, 1))
    agents.append({
        "agent_id":       f"AGT{i:04d}",
        "agent_name":     fake.name(),
        "agency_name":    fake.company(),
        "state":          random.choice(STATES),
        "email":          fake.email(),
        "phone":          fake.phone_number(),
        "hire_date":      hire_date,
        "is_active":      random.choices([True, False], weights=[0.88, 0.12])[0],
        "tier":           random.choices(["bronze", "silver", "gold", "platinum"],
                                          weights=[0.40, 0.30, 0.20, 0.10])[0],
    })

df_agents = pd.DataFrame(agents)
df_agents.to_csv(f"{OUTPUT_DIR}/agents.csv", index=False)
print(f"  → {len(df_agents)} agents")

# ── 2. Members ────────────────────────────────────────────────────────────────
print("Generating members...")
agent_ids = df_agents["agent_id"].tolist()
members = []
for i in range(1, N_MEMBERS + 1):
    enroll_date = rand_date(START_DATE, END_DATE - timedelta(days=30))
    dob = rand_date(date(1950, 1, 1), date(2003, 12, 31))
    members.append({
        "member_id":          f"MEM{i:06d}",
        "first_name":         fake.first_name(),
        "last_name":          fake.last_name(),
        "email":              fake.email(),
        "phone":              fake.phone_number(),
        "dob":                dob,
        "state":              random.choice(STATES),
        "zip_code":           fake.zipcode(),
        "enrollment_date":    enroll_date,
        "agent_id":           random.choice(agent_ids),
        "carrier":            random.choice(CARRIERS),
        "plan_type":          random.choices(
                                  list(PLAN_PREMIUMS.keys()),
                                  weights=[0.25, 0.20, 0.20, 0.15, 0.20]
                              )[0],
    })

df_members = pd.DataFrame(members)
df_members.to_csv(f"{OUTPUT_DIR}/members.csv", index=False)
print(f"  → {len(df_members)} members")

# ── 3. Policies ───────────────────────────────────────────────────────────────
print("Generating policies...")
policies = []
for _, m in df_members.iterrows():
    enroll = pd.to_datetime(m["enrollment_date"]).date()
    # effective date = first of following month
    eff_month = enroll.replace(day=1) + timedelta(days=32)
    effective_date = eff_month.replace(day=1)
    # random term 6-36 months
    term_months = random.choices([6, 12, 24, 36], weights=[0.10, 0.55, 0.25, 0.10])[0]
    expiry_date = date_range_months(effective_date, term_months)

    premium = PLAN_PREMIUMS[m["plan_type"]]
    # introduce small pricing noise ±5%
    actual_premium = round(premium * random.uniform(0.95, 1.05), 2)

    status = random.choices(
        ["active", "cancelled", "expired", "pending"],
        weights=[0.62, 0.20, 0.15, 0.03]
    )[0]

    policies.append({
        "policy_id":           f"POL{_:07d}",
        "member_id":           m["member_id"],
        "agent_id":            m["agent_id"],
        "carrier":             m["carrier"],
        "plan_type":           m["plan_type"],
        "effective_date":      effective_date,
        "expiry_date":         expiry_date,
        "monthly_premium":     actual_premium,
        "annual_premium":      round(actual_premium * 12, 2),
        "commission_rate":     COMMISSION_RATES[m["plan_type"]],
        "monthly_commission":  round(actual_premium * COMMISSION_RATES[m["plan_type"]], 2),
        "status":              status,
        "term_months":         term_months,
    })

df_policies = pd.DataFrame(policies)
df_policies.to_csv(f"{OUTPUT_DIR}/policies.csv", index=False)
print(f"  → {len(df_policies)} policies")

# ── 4. Payments ───────────────────────────────────────────────────────────────
print("Generating payments...")
payments = []
pay_id = 1

for _, p in df_policies.iterrows():
    if p["status"] == "pending":
        continue

    eff = pd.to_datetime(p["effective_date"]).date()
    exp = pd.to_datetime(p["expiry_date"]).date()
    exp = min(exp, END_DATE)

    current = eff
    while current <= exp:
        # 92% on-time, 5% late, 3% failed
        outcome = random.choices(
            ["paid", "paid_late", "failed"],
            weights=[0.92, 0.05, 0.03]
        )[0]

        due_date = current
        paid_date = None
        amount_paid = 0.0

        if outcome == "paid":
            paid_date = due_date + timedelta(days=random.randint(0, 3))
            amount_paid = p["monthly_premium"]
        elif outcome == "paid_late":
            paid_date = due_date + timedelta(days=random.randint(4, 30))
            amount_paid = p["monthly_premium"]
        # failed → paid_date stays None, amount 0

        payments.append({
            "payment_id":     f"PAY{pay_id:08d}",
            "policy_id":      p["policy_id"],
            "member_id":      p["member_id"],
            "due_date":       due_date,
            "paid_date":      paid_date,
            "amount_due":     p["monthly_premium"],
            "amount_paid":    round(amount_paid, 2),
            "payment_status": outcome,
            "payment_method": random.choice(PAYMENT_METHODS),
            "carrier":        p["carrier"],
            "plan_type":      p["plan_type"],
        })
        pay_id += 1

        # advance one month
        m2 = current.month % 12 + 1
        y2 = current.year + (1 if current.month == 12 else 0)
        current = current.replace(year=y2, month=m2)

df_payments = pd.DataFrame(payments)
df_payments.to_csv(f"{OUTPUT_DIR}/payments.csv", index=False)
print(f"  → {len(df_payments)} payment records")

# ── 5. Cancellations ──────────────────────────────────────────────────────────
print("Generating cancellations...")
cancelled_policies = df_policies[df_policies["status"] == "cancelled"]
cancellations = []

for _, p in cancelled_policies.iterrows():
    eff = pd.to_datetime(p["effective_date"]).date()
    exp = pd.to_datetime(p["expiry_date"]).date()
    cancel_date = rand_date(eff + timedelta(days=30), min(exp, END_DATE))

    reason = random.choices(
        CANCEL_REASONS,
        weights=[0.35, 0.25, 0.15, 0.10, 0.10, 0.05]
    )[0]

    months_active = max(1, (cancel_date - eff).days // 30)
    lifetime_value = round(p["monthly_premium"] * months_active, 2)

    cancellations.append({
        "cancellation_id":    f"CAN{len(cancellations)+1:06d}",
        "policy_id":          p["policy_id"],
        "member_id":          p["member_id"],
        "agent_id":           p["agent_id"],
        "cancellation_date":  cancel_date,
        "cancellation_reason":reason,
        "months_active":      months_active,
        "lifetime_value":     lifetime_value,
        "carrier":            p["carrier"],
        "plan_type":          p["plan_type"],
        "was_payment_failure":reason == "non_payment",
    })

df_cancellations = pd.DataFrame(cancellations)
df_cancellations.to_csv(f"{OUTPUT_DIR}/cancellations.csv", index=False)
print(f"  → {len(df_cancellations)} cancellations")

# ── Summary ───────────────────────────────────────────────────────────────────
print("\n✅ All seed files written to /seeds/")
print(f"   agents.csv          {len(df_agents):>6,} rows")
print(f"   members.csv         {len(df_members):>6,} rows")
print(f"   policies.csv        {len(df_policies):>6,} rows")
print(f"   payments.csv        {len(df_payments):>6,} rows")
print(f"   cancellations.csv   {len(df_cancellations):>6,} rows")
print(f"\n   Total rows: {len(df_agents)+len(df_members)+len(df_policies)+len(df_payments)+len(df_cancellations):,}")

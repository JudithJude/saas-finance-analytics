"""Generate fake API data for Stripe, HubSpot, the app database and Heap.

The extractors read these files as if they were API responses, so the whole
pipeline runs end to end without any real accounts or keys.

Run:  python -m include.generate_fake_data
"""

from __future__ import annotations

import json
import random
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

SEED = 42
OUT_DIR = Path(__file__).resolve().parent.parent / "data" / "fake_api"
START = date(2025, 1, 1)
END = date(2026, 11, 27)  # "today" for the fake data
N_COMPANIES = 120

# Must match dbt/seeds/plan_prices.csv
PLANS = {
    "starter_monthly": ("month", 8900),
    "pro_monthly": ("month", 19900),
    "enterprise_monthly": ("month", 49900),
    "starter_yearly": ("year", 89000),
    "pro_yearly": ("year", 199000),
}
UPGRADE = {"starter_monthly": "pro_monthly", "pro_monthly": "enterprise_monthly"}
DOWNGRADE = {"enterprise_monthly": "pro_monthly", "pro_monthly": "starter_monthly"}

WORDS = ["nova", "brightline", "atlas", "kite", "lumen", "orbit", "pine", "quarry",
         "river", "summit", "tidal", "vertex", "willow", "zephyr", "harbor", "maple"]
SUFFIX = ["labs", "studio", "media", "digital", "group", "co", "agency", "brands"]


def ts(d: date | datetime) -> str:
    if isinstance(d, date) and not isinstance(d, datetime):
        d = datetime(d.year, d.month, d.day, 9, 0, tzinfo=timezone.utc)
    return d.isoformat()


def add_months(d: date, n: int) -> date:
    m = d.month - 1 + n
    return date(d.year + m // 12, m % 12 + 1, 1)


def month_starts(a: date, b: date):
    d = date(a.year, a.month, 1)
    while d <= b:
        yield d
        d = add_months(d, 1)


def main() -> None:
    rnd = random.Random(SEED)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    customers, subscriptions, invoices = [], [], []
    companies, deals, accounts, prompt_runs, heap_events = [], [], [], [], []
    inv_n = 0

    for i in range(1, N_COMPANIES + 1):
        name = f"{rnd.choice(WORDS).title()} {rnd.choice(SUFFIX).title()}"
        domain = f"{name.lower().replace(' ', '')}{i}.com"
        currency = "usd" if rnd.random() < 0.3 else "eur"
        lead_day = START + timedelta(days=rnd.randint(0, (END - START).days - 30))
        company_id = str(1000 + i)
        stripe_id = f"cus_{i:05d}"

        # Some customers never convert, some convert after a trial.
        converts = rnd.random() < 0.75
        stage = "closedwon" if converts else rnd.choice(["closedlost", "appointmentscheduled", "qualifiedtobuy"])
        close_day = min(lead_day + timedelta(days=rnd.randint(7, 45)), END)
        start_month = add_months(close_day, 1) if converts else None
        if converts and start_month > END:
            converts, stage = False, "qualifiedtobuy"

        companies.append({
            "id": company_id, "updatedAt": ts(lead_day),
            "properties": {"name": name, "domain": domain,
                           # A few companies are missing the Stripe ID, so dbt must fall back to the domain.
                           "stripe_customer_id": stripe_id if converts and rnd.random() > 0.1 else None,
                           "createdate": ts(lead_day)},
        })
        deals.append({
            "id": f"d{i}", "updatedAt": ts(close_day),
            "properties": {"company_id": company_id, "dealstage": stage,
                           "amount": rnd.choice([1068, 2388, 5988]),
                           "createdate": ts(lead_day),
                           "closedate": ts(close_day) if stage in ("closedwon", "closedlost") else None},
        })
        accounts.append({"id": f"acc_{i:05d}", "company_domain": domain,
                         "created_at": ts(lead_day), "updated_at": ts(lead_day)})

        if not converts:
            continue

        customers.append({"id": stripe_id, "email": f"billing@{domain}", "name": name,
                          "currency": currency, "created": ts(close_day), "updated": ts(close_day)})

        plan = rnd.choice(list(PLANS))
        sub_id = f"sub_{i:05d}"
        churn_month = add_months(start_month, rnd.randint(3, 20)) if rnd.random() < 0.3 else None
        # 20% of customers get 10% off their first three invoices.
        has_intro_discount = rnd.random() < 0.2
        month = start_month
        last_paid = None
        n_invoices = 0
        while month <= END and (churn_month is None or month < churn_month):
            interval, price = PLANS[plan]
            months_covered = 12 if interval == "year" else 1
            period_end = add_months(month, months_covered)
            discount = price // 10 if has_intro_discount and n_invoices < 3 else 0
            n_invoices += 1
            fx = 1.0 if currency == "eur" else 1.08  # prices are set in the customer's currency
            amount = int((price - discount) * fx)
            status = "paid"
            if rnd.random() < 0.03:
                status = "uncollectible"  # failed payment: excluded from MRR
            inv_n += 1
            invoices.append({
                "id": f"in_{inv_n:06d}", "customer": stripe_id, "subscription": sub_id,
                "status": status, "currency": currency, "amount_due": amount,
                "amount_paid": amount if status == "paid" else 0, "discount": discount,
                "plan_id": plan, "period_start": ts(month), "period_end": ts(period_end),
                "created": ts(month), "updated": ts(month + timedelta(days=3)),
            })
            last_paid = month
            # Monthly plans sometimes upgrade or downgrade.
            if interval == "month":
                r = rnd.random()
                if r < 0.05 and plan in UPGRADE:
                    plan = UPGRADE[plan]
                elif r < 0.07 and plan in DOWNGRADE:
                    plan = DOWNGRADE[plan]
            month = period_end

        canceled = churn_month is not None and churn_month <= END
        subscriptions.append({
            "id": sub_id, "customer": stripe_id, "plan_id": plan,
            "status": "canceled" if canceled else "active",
            "start_date": ts(start_month),
            "canceled_at": ts(churn_month) if canceled else None,
            "updated": ts(churn_month if canceled else last_paid),
        })

        # Product usage while the customer is active.
        for day_n in range(0, (min(END, churn_month or END) - start_month).days, 7):
            day = start_month + timedelta(days=day_n)
            prompt_runs.append({"id": f"pr_{i}_{day_n}", "account_id": f"acc_{i:05d}",
                                "run_date": day.isoformat(), "prompts_run": rnd.randint(20, 400),
                                "brands_tracked": rnd.randint(1, 8), "updated_at": ts(day)})
            heap_events.append({"id": f"ev_{i}_{day_n}", "account_id": f"acc_{i:05d}",
                                "event": rnd.choice(["viewed_dashboard", "exported_report", "added_prompt"]),
                                "time": ts(day)})

    files = {
        "stripe_customers.json": customers, "stripe_subscriptions.json": subscriptions,
        "stripe_invoices.json": invoices, "hubspot_companies.json": companies,
        "hubspot_deals.json": deals, "app_db_accounts.json": accounts,
        "app_db_prompt_runs.json": prompt_runs, "heap_events.json": heap_events,
    }
    for name, rows in files.items():
        (OUT_DIR / name).write_text(json.dumps(rows, indent=1))
        print(f"{name}: {len(rows)} rows")


if __name__ == "__main__":
    main()

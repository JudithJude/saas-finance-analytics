# Metabase

Metabase reads only the `marts` schema, never `raw` or `staging`, so every chart uses tested, agreed numbers.

## Connect

1. `make up` (or `astro dev start`), then open http://localhost:3000 and create an admin user.
2. Add a database: **PostgreSQL**, host `warehouse`, port `5432`, database `warehouse`, user `postgres`, password `postgres`.
3. Under **Schemas**, choose "Only these" and pick `marts` (prod) or `dev_marts` (local dev target).
4. In **Table metadata**, hide `int_*` tables if they show up, and add the descriptions from `docs/metric_definitions.md`.

## Revenue dashboard (for finance)

All from `rpt_mrr_monthly`:

| Card | Chart | Settings |
|---|---|---|
| MRR now | Number | `mrr_eur`, latest month, compared with previous month |
| ARR now | Number | `arr_eur`, latest month |
| Paying customers | Number | `paying_customers`, latest month |
| MRR over time | Line | x = `month`, y = `mrr_eur` |
| MRR movements | Stacked bar | x = `month`; `new_mrr_eur`, `reactivation_mrr_eur`, `expansion_mrr_eur` up; `contraction_mrr_eur`, `churned_mrr_eur` shown as negatives |
| Retention | Line | `net_revenue_retention`, `gross_revenue_retention` |
| Churn | Line | `customer_churn_rate`, `revenue_churn_rate` |

## Other dashboards

- **Customers** (`dim_customers`, `fct_mrr`): top customers by `current_mrr_eur`, plan mix, customers by `hubspot_match_method` (anything `unmatched` needs fixing in HubSpot).
- **Usage** (`fct_usage_daily`): prompts run per week, active accounts, usage of customers who later churned.
- **Pipeline** (`fct_pipeline`): deals by stage, win rate, median `days_to_close`.

## Self-serve

Turn `rpt_mrr_monthly`, `dim_customers` and `fct_mrr` into Metabase **models** and mark them as verified, so business teams build their own questions from trusted tables.

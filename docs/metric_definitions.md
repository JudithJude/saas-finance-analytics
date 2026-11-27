# Metric definitions

How every revenue number in this project is calculated, in plain words. If a dashboard and this page disagree, this page wins, and the dashboard is a bug.

Every metric below comes from `rpt_mrr_monthly`, which is built from `fct_mrr` and `fct_mrr_movements`.

## Ground rules

| Rule | What we do | Why |
|---|---|---|
| Which invoices count | `paid` and `open` invoices. `void` and `uncollectible` (failed payment) don't count. | A failed payment isn't revenue. If the customer pays again later, it shows up as a reactivation. |
| Discounts | MRR is **net** of discounts (`amount_due`). | It's what the customer actually pays. When an intro discount ends, MRR goes up and shows as expansion. |
| Yearly plans | Spread evenly over the 12 months they cover. | A €1,990 yearly plan is €165.83 of MRR each month, not €1,990 in one month. |
| Future months | MRR stops at the reporting month (the current month by default). | A yearly plan paid in advance must not create MRR for months that haven't happened. The rest is **deferred** and still accounted for (see the reconciliation test). |
| Currency | Everything in EUR, at a fixed planning rate per currency (`seeds/fx_rates.csv`). | Otherwise a USD customer would look like expansion or contraction every month just because the exchange rate moved. |
| Month | Calendar month, first day of the month (`2026-11-01` = November 2026). | One point in time for every report. |

## Revenue

| Metric | Definition | Column |
|---|---|---|
| **MRR** | Sum of every paying customer's monthly amount in the month. | `mrr_eur` |
| **ARR** | MRR × 12. | `arr_eur` |
| **ARPA** | MRR ÷ paying customers. | `arpa_eur` |

## MRR movements

Each customer, each month, gets exactly one label (`fct_mrr_movements.movement_type`):

| Movement | Meaning |
|---|---|
| `new` | First month the customer pays. |
| `expansion` | Pays more than last month (upgrade, discount ended). |
| `contraction` | Pays less than last month but still pays (downgrade). |
| `churn` | Paid last month, pays nothing this month. |
| `reactivation` | Paid nothing last month, pays again. |
| `retained` | Same as last month. |

They always add up: **starting MRR + new + reactivation + expansion − contraction − churned = ending MRR.**
`tests/assert_mrr_movements_balance.sql` fails the build if any month doesn't.

## Churn and retention (monthly)

| Metric | Definition | Column |
|---|---|---|
| **Customer churn rate** | Customers who churned ÷ customers paying at the start of the month. | `customer_churn_rate` |
| **Revenue churn rate** | Churned MRR ÷ starting MRR. | `revenue_churn_rate` |
| **Net revenue retention (NRR)** | (Starting MRR + expansion − contraction − churned) ÷ starting MRR. New customers are left out. Above 100% means existing customers grow faster than you lose them. | `net_revenue_retention` |
| **Gross revenue retention (GRR)** | (Starting MRR − contraction − churned) ÷ starting MRR. Never above 100%. | `gross_revenue_retention` |

These are monthly. For a yearly NRR, compare one cohort's MRR today with the same customers' MRR 12 months ago.

## Checks that protect these numbers

- `assert_mrr_movements_balance`: movements add up every month.
- `assert_mrr_ties_to_invoices`: invoiced amount = MRR recognised + amount deferred to future months. Nothing is lost or counted twice.
- `assert_no_negative_mrr`: MRR is never negative.
- Grain tests: `fct_mrr` and `fct_mrr_movements` have exactly one row per customer per month.
- Unit test `test_mrr_movement_types`: each kind of change gets the right label.

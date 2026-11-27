-- The monthly revenue report finance and investors look at.
-- Grain: one row per month.

with movements as (
    select * from {{ ref('fct_mrr_movements') }}
),

monthly as (
    select
        month,
        sum(starting_mrr_eur) as starting_mrr_eur,
        sum(new_mrr_eur) as new_mrr_eur,
        sum(reactivation_mrr_eur) as reactivation_mrr_eur,
        sum(expansion_mrr_eur) as expansion_mrr_eur,
        sum(contraction_mrr_eur) as contraction_mrr_eur,
        sum(churned_mrr_eur) as churned_mrr_eur,
        sum(ending_mrr_eur) as ending_mrr_eur,
        count(*) filter (where starting_mrr_eur > 0) as starting_customers,
        count(*) filter (where movement_type = 'new') as new_customers,
        count(*) filter (where movement_type = 'churn') as churned_customers,
        count(*) filter (where ending_mrr_eur > 0) as paying_customers
    from movements
    group by month
)

select
    month,
    starting_mrr_eur,
    new_mrr_eur,
    reactivation_mrr_eur,
    expansion_mrr_eur,
    contraction_mrr_eur,
    churned_mrr_eur,
    ending_mrr_eur as mrr_eur,
    ending_mrr_eur * 12 as arr_eur,
    paying_customers,
    new_customers,
    churned_customers,
    round(ending_mrr_eur / nullif(paying_customers, 0), 2) as arpa_eur,
    round(churned_customers::numeric / nullif(starting_customers, 0), 4) as customer_churn_rate,
    round(churned_mrr_eur / nullif(starting_mrr_eur, 0), 4) as revenue_churn_rate,
    round(
        (starting_mrr_eur + expansion_mrr_eur - contraction_mrr_eur - churned_mrr_eur)
        / nullif(starting_mrr_eur, 0),
        4
    ) as net_revenue_retention,
    round(
        (starting_mrr_eur - contraction_mrr_eur - churned_mrr_eur) / nullif(starting_mrr_eur, 0),
        4
    ) as gross_revenue_retention
from monthly

-- How each customer's MRR changed from last month to this month.
-- Grain: one row per customer per month, from their first paying month until
-- the month after they stop paying (that's the month the churn shows up).
--
--   new           first month a customer pays
--   expansion     pays more than last month
--   contraction   pays less, but still pays
--   churn         paid last month, pays nothing this month
--   reactivation  paid nothing last month, pays again
--   retained      same as last month

with mrr as (
    select
        customer_id,
        month,
        mrr_eur
    from {{ ref('fct_mrr') }}
),

reporting_end as (
    select max(month) as last_month from mrr
),

customer_bounds as (
    select
        customer_id,
        min(month) as first_month,
        max(month) as last_month
    from mrr
    group by customer_id
),

spine as (
    select
        customer_bounds.customer_id,
        customer_bounds.first_month,
        month_series.series_month::date as month
    from customer_bounds
    cross join reporting_end
    cross join lateral generate_series(
        customer_bounds.first_month,
        least(customer_bounds.last_month + interval '1 month', reporting_end.last_month),
        interval '1 month'
    ) as month_series (series_month)
),

filled as (
    select
        spine.customer_id,
        spine.month,
        spine.month = spine.first_month as is_first_month,
        coalesce(mrr.mrr_eur, 0) as ending_mrr_eur
    from spine
    left join mrr
        on
            spine.customer_id = mrr.customer_id
            and spine.month = mrr.month
),

with_previous as (
    select
        *,
        coalesce(
            lag(ending_mrr_eur) over (partition by customer_id order by month),
            0
        ) as starting_mrr_eur
    from filled
),

classified as (
    select
        *,
        case
            when is_first_month then 'new'
            when starting_mrr_eur = 0 and ending_mrr_eur > 0 then 'reactivation'
            when starting_mrr_eur > 0 and ending_mrr_eur = 0 then 'churn'
            when ending_mrr_eur > starting_mrr_eur then 'expansion'
            when ending_mrr_eur < starting_mrr_eur then 'contraction'
            else 'retained'
        end as movement_type
    from with_previous
    where not (starting_mrr_eur = 0 and ending_mrr_eur = 0)
)

select
    {{ dbt.concat(["customer_id", "'-'", "to_char(month, 'YYYY-MM')"]) }} as customer_month_id,
    customer_id,
    month,
    movement_type,
    starting_mrr_eur,
    ending_mrr_eur,
    case when movement_type = 'new' then ending_mrr_eur else 0 end as new_mrr_eur,
    case when movement_type = 'reactivation' then ending_mrr_eur else 0 end as reactivation_mrr_eur,
    case when movement_type = 'expansion' then ending_mrr_eur - starting_mrr_eur else 0 end as expansion_mrr_eur,
    case when movement_type = 'contraction' then starting_mrr_eur - ending_mrr_eur else 0 end as contraction_mrr_eur,
    case when movement_type = 'churn' then starting_mrr_eur else 0 end as churned_mrr_eur
from classified

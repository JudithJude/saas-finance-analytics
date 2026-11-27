-- One row per paying customer, with their IDs across tools and where they stand today.

with ids as (
    select * from {{ ref('int_customer_ids') }}
),

mrr as (
    select * from {{ ref('fct_mrr') }}
),

reporting_end as (
    select max(month) as last_month from mrr
),

customer_mrr as (
    select
        customer_id,
        min(month) as first_paid_month,
        max(month) as last_paid_month,
        (array_agg(plan_id order by month desc))[1] as latest_plan_id,
        (array_agg(mrr_eur order by month desc))[1] as latest_mrr_eur
    from mrr
    group by customer_id
),

subscriptions as (
    select
        customer_id,
        (array_agg(subscription_status order by started_at desc))[1] as subscription_status
    from {{ ref('stg_stripe__subscriptions') }}
    group by customer_id
)

select
    ids.customer_id,
    ids.customer_name,
    ids.email_domain,
    ids.currency,
    ids.hubspot_company_id,
    ids.hubspot_match_method,
    ids.app_account_id,
    subscriptions.subscription_status,
    customer_mrr.first_paid_month,
    customer_mrr.last_paid_month,
    customer_mrr.latest_plan_id,
    coalesce(customer_mrr.last_paid_month = reporting_end.last_month, false) as is_paying_now,
    case
        when customer_mrr.last_paid_month = reporting_end.last_month then customer_mrr.latest_mrr_eur
        else 0
    end as current_mrr_eur
from ids
cross join reporting_end
left join customer_mrr
    on ids.customer_id = customer_mrr.customer_id
left join subscriptions
    on ids.customer_id = subscriptions.customer_id

-- One row per paying (Stripe) customer, with its ID in every other tool.
-- HubSpot is matched on the Stripe ID stored on the company first,
-- then on email domain when that field is empty.

with customers as (
    select * from {{ ref('stg_stripe__customers') }}
),

companies as (
    select * from {{ ref('stg_hubspot__companies') }}
),

accounts as (
    select * from {{ ref('stg_app__accounts') }}
)

select
    customers.customer_id,
    coalesce(by_id.company_name, by_domain.company_name, customers.customer_name) as customer_name,
    customers.email_domain,
    customers.currency,
    coalesce(by_id.company_id, by_domain.company_id) as hubspot_company_id,
    case
        when by_id.company_id is not null then 'stripe_id'
        when by_domain.company_id is not null then 'email_domain'
        else 'unmatched'
    end as hubspot_match_method,
    accounts.account_id as app_account_id
from customers
left join companies as by_id
    on customers.customer_id = by_id.stripe_customer_id
left join companies as by_domain
    on
        by_id.company_id is null
        and customers.email_domain = by_domain.company_domain
left join accounts
    on customers.email_domain = accounts.company_domain

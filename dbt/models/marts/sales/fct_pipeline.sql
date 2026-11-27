-- One row per deal, with how long it took to close and the paying customer it became.

with deals as (
    select * from {{ ref('stg_hubspot__deals') }}
)

select
    deals.deal_id,
    deals.company_id as hubspot_company_id,
    ids.customer_id,
    deals.deal_stage,
    deals.deal_stage = 'closedwon' as is_won,
    deals.deal_stage in ('closedwon', 'closedlost') as is_closed,
    deals.deal_amount,
    deals.created_at,
    deals.closed_at,
    (deals.closed_at::date - deals.created_at::date) as days_to_close
from deals
left join {{ ref('int_customer_ids') }} as ids
    on deals.company_id = ids.hubspot_company_id

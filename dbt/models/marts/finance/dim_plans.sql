-- One row per plan. Prices come from seeds/plan_prices.csv.

select
    plan_id,
    plan_name,
    tier,
    billing_interval,
    {{ cents_to_units('list_price_cents') }} as list_price,
    case
        when billing_interval = 'year' then {{ cents_to_units('list_price_cents') }} / 12
        else {{ cents_to_units('list_price_cents') }}
    end as list_price_per_month
from {{ ref('plan_prices') }}

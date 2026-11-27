with source as (
    select * from {{ source('stripe', 'subscriptions') }}
)

select
    record ->> 'id' as subscription_id,
    record ->> 'customer' as customer_id,
    record ->> 'plan_id' as plan_id,
    record ->> 'status' as subscription_status,
    (record ->> 'start_date')::timestamptz as started_at,
    (record ->> 'canceled_at')::timestamptz as canceled_at,
    updated_at,
    _loaded_at
from source

with source as (
    select * from {{ source('stripe', 'invoices') }}
)

select
    record ->> 'id' as invoice_id,
    record ->> 'customer' as customer_id,
    record ->> 'subscription' as subscription_id,
    record ->> 'plan_id' as plan_id,
    record ->> 'status' as invoice_status,
    upper(record ->> 'currency') as currency,
    -- amount_due is already net of discounts
    {{ cents_to_units("(record ->> 'amount_due')::bigint") }} as amount_due,
    {{ cents_to_units("(record ->> 'amount_paid')::bigint") }} as amount_paid,
    {{ cents_to_units("(record ->> 'discount')::bigint") }} as discount_amount,
    (record ->> 'period_start')::timestamptz::date as period_start,
    (record ->> 'period_end')::timestamptz::date as period_end,
    (record ->> 'created')::timestamptz as created_at,
    updated_at,
    _loaded_at
from source

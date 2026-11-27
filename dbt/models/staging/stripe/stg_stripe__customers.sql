with source as (
    select * from {{ source('stripe', 'customers') }}
)

select
    record ->> 'id' as customer_id,
    record ->> 'name' as customer_name,
    lower(record ->> 'email') as email,
    split_part(lower(record ->> 'email'), '@', 2) as email_domain,
    upper(record ->> 'currency') as currency,
    (record ->> 'created')::timestamptz as created_at,
    updated_at,
    _loaded_at
from source

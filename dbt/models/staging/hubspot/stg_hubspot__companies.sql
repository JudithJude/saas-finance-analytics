with source as (
    select * from {{ source('hubspot', 'companies') }}
)

select
    record ->> 'id' as company_id,
    record -> 'properties' ->> 'name' as company_name,
    lower(record -> 'properties' ->> 'domain') as company_domain,
    nullif(record -> 'properties' ->> 'stripe_customer_id', '') as stripe_customer_id,
    (record -> 'properties' ->> 'createdate')::timestamptz as created_at,
    updated_at,
    _loaded_at
from source

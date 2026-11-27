with source as (
    select * from {{ source('app_db', 'accounts') }}
)

select
    record ->> 'id' as account_id,
    lower(record ->> 'company_domain') as company_domain,
    (record ->> 'created_at')::timestamptz as created_at,
    updated_at,
    _loaded_at
from source

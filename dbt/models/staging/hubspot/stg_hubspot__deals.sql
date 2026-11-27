with source as (
    select * from {{ source('hubspot', 'deals') }}
)

select
    record ->> 'id' as deal_id,
    record -> 'properties' ->> 'company_id' as company_id,
    record -> 'properties' ->> 'dealstage' as deal_stage,
    (record -> 'properties' ->> 'amount')::numeric as deal_amount,
    (record -> 'properties' ->> 'createdate')::timestamptz as created_at,
    (record -> 'properties' ->> 'closedate')::timestamptz as closed_at,
    updated_at,
    _loaded_at
from source

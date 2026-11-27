with source as (
    select * from {{ source('heap', 'events') }}
)

select
    record ->> 'id' as event_id,
    record ->> 'account_id' as account_id,
    record ->> 'event' as event_name,
    (record ->> 'time')::timestamptz as event_at,
    _loaded_at
from source

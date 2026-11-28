-- Personal data (name, email) lives here and nowhere downstream except name in dim_customers.
-- Customers on the erasure list keep their financial history, but lose their personal fields.

with source as (
    select * from {{ source('stripe', 'customers') }}
),

erasures as (
    select * from {{ ref('privacy_erasures') }}
)

select
    source.record ->> 'id' as customer_id,
    case when erasures.customer_id is null then source.record ->> 'name' end as customer_name,
    case when erasures.customer_id is null then lower(source.record ->> 'email') end as email,
    case
        when erasures.customer_id is null then split_part(lower(source.record ->> 'email'), '@', 2)
    end as email_domain,
    upper(source.record ->> 'currency') as currency,
    (source.record ->> 'created')::timestamptz as created_at,
    erasures.customer_id is not null as is_erased,
    source.updated_at,
    source._loaded_at
from source
left join erasures
    on source.record ->> 'id' = erasures.customer_id

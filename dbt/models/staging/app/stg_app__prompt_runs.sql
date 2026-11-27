with source as (
    select * from {{ source('app_db', 'prompt_runs') }}
)

select
    record ->> 'id' as prompt_run_id,
    record ->> 'account_id' as account_id,
    (record ->> 'run_date')::date as run_date,
    (record ->> 'prompts_run')::int as prompts_run,
    (record ->> 'brands_tracked')::int as brands_tracked,
    updated_at,
    _loaded_at
from source

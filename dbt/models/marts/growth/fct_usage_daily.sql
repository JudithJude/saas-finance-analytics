-- Product usage per account per day: prompts run in the app plus Heap events.
-- Grain: one row per account per day with any activity.

with prompt_runs as (
    select
        account_id,
        run_date as activity_date,
        sum(prompts_run) as prompts_run,
        max(brands_tracked) as brands_tracked
    from {{ ref('stg_app__prompt_runs') }}
    group by account_id, run_date
),

events as (
    select
        account_id,
        event_at::date as activity_date,
        count(*) as heap_events
    from {{ ref('stg_heap__events') }}
    group by account_id, event_at::date
),

combined as (
    select
        coalesce(prompt_runs.account_id, events.account_id) as account_id,
        coalesce(prompt_runs.activity_date, events.activity_date) as activity_date,
        coalesce(prompt_runs.prompts_run, 0) as prompts_run,
        coalesce(prompt_runs.brands_tracked, 0) as brands_tracked,
        coalesce(events.heap_events, 0) as heap_events
    from prompt_runs
    full outer join events
        on
            prompt_runs.account_id = events.account_id
            and prompt_runs.activity_date = events.activity_date
)

select
    combined.*,
    ids.customer_id
from combined
left join {{ ref('int_customer_ids') }} as ids
    on combined.account_id = ids.app_account_id

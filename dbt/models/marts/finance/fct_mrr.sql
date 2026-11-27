-- MRR per customer per month, in EUR.
-- Grain: one row per customer per month in which they were paying.
-- Every revenue number in Metabase starts from this table.

with invoice_months as (
    select * from {{ ref('int_invoice_months') }}
)

select
    {{ dbt.concat(["customer_id", "'-'", "to_char(month, 'YYYY-MM')"]) }} as customer_month_id,
    customer_id,
    month,
    (array_agg(plan_id order by invoice_id desc))[1] as plan_id,
    round(sum(monthly_amount_eur), 2) as mrr_eur,
    count(distinct invoice_id) as invoice_count
from invoice_months
where month <= {{ reporting_month() }}
group by customer_id, month

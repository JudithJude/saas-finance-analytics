-- Spreads each invoice across the months it pays for.
-- A yearly invoice becomes 12 rows of one twelfth each, so MRR stays smooth.
-- Grain: one row per invoice per month.
--
-- Rules agreed with finance (see docs/metric_definitions.md):
--   * paid and open invoices count; void and uncollectible (failed payment) don't
--   * amounts are net of discounts
--   * everything is converted to EUR at a fixed planning rate (seeds/fx_rates.csv)

with invoices as (
    select * from {{ ref('stg_stripe__invoices') }}
    where invoice_status in ('paid', 'open')
),

fx as (
    select * from {{ ref('fx_rates') }}
),

spread as (
    select
        invoices.invoice_id,
        invoices.customer_id,
        invoices.subscription_id,
        invoices.plan_id,
        invoices.currency,
        invoices.amount_due,
        {{ months_between('invoices.period_start', 'invoices.period_end') }} as months_in_period,
        month_series.series_month::date as month
    from invoices
    cross join lateral generate_series(
        date_trunc('month', invoices.period_start),
        invoices.period_end - interval '1 day',
        interval '1 month'
    ) as month_series (series_month)
)

select
    spread.invoice_id,
    spread.customer_id,
    spread.subscription_id,
    spread.plan_id,
    spread.month,
    spread.currency,
    spread.months_in_period,
    spread.amount_due / spread.months_in_period as monthly_amount,
    spread.amount_due / spread.months_in_period * fx.rate_to_eur as monthly_amount_eur
from spread
inner join fx
    on spread.currency = fx.currency

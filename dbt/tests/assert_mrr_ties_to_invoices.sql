-- Reconciliation: every countable invoice must be fully accounted for.
-- Invoiced amount = MRR recognised up to the reporting month + amount deferred to later months
-- (e.g. the rest of a yearly plan paid up front). Small rounding is allowed: a cent per row.

with invoiced as (
    select sum(inv.amount_due * fx.rate_to_eur) as invoiced_eur
    from {{ ref('stg_stripe__invoices') }} as inv
    inner join {{ ref('fx_rates') }} as fx on inv.currency = fx.currency
    where inv.invoice_status in ('paid', 'open')
),

recognised as (
    select
        sum(mrr_eur) as recognised_eur,
        count(*) as row_count
    from {{ ref('fct_mrr') }}
),

deferred as (
    select
        coalesce(sum(monthly_amount_eur), 0) as deferred_eur,
        count(*) as row_count
    from {{ ref('int_invoice_months') }}
    where month > {{ reporting_month() }}
)

select
    invoiced.invoiced_eur,
    recognised.recognised_eur,
    deferred.deferred_eur
from invoiced
cross join recognised
cross join deferred
where
    abs(invoiced.invoiced_eur - recognised.recognised_eur - deferred.deferred_eur)
    > (recognised.row_count + deferred.row_count) * 0.01

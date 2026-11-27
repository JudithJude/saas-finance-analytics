-- MRR can be zero, never negative. A negative value usually means a refund was counted as revenue.

select * from {{ ref('fct_mrr') }}
where mrr_eur < 0

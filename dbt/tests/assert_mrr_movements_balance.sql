-- Finance's first check: starting MRR + every movement must equal ending MRR, each month.
-- Any row returned is a month that doesn't tie out, and fails the build.

select
    month,
    starting_mrr_eur,
    new_mrr_eur,
    reactivation_mrr_eur,
    expansion_mrr_eur,
    contraction_mrr_eur,
    churned_mrr_eur,
    mrr_eur
from {{ ref('rpt_mrr_monthly') }}
where abs(
    starting_mrr_eur + new_mrr_eur + reactivation_mrr_eur + expansion_mrr_eur
    - contraction_mrr_eur - churned_mrr_eur - mrr_eur
) > 0.01

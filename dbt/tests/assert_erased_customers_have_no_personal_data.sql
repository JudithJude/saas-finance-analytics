-- A customer who asked to be forgotten keeps their invoices and MRR history,
-- but no name, email or email domain anywhere in staging.

select customer_id
from {{ ref('stg_stripe__customers') }}
where
    is_erased
    and (customer_name is not null or email is not null or email_domain is not null)

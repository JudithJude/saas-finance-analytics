# Personal data and GDPR

Finance needs customer data, and some of it is personal: names and email addresses from Stripe. This page covers where that data sits, who can see it, and what happens when a customer asks to be forgotten.

## Where personal data lives

| Layer | Personal data | Who can read it |
|---|---|---|
| `raw.stripe_customers` | Name, email (as Stripe sent them) | The loader and the data team only |
| `staging.stg_stripe__customers` | Name, email, email domain | The data team only |
| `marts.dim_customers` | Company name and email domain, never a personal email | Finance, Metabase, the AI analytics tool |

Columns that hold personal data are tagged `meta: {contains_pii: true}` in the model YAML, so they show up in the dbt docs and can be found with:

```bash
grep -rn contains_pii dbt/models
```

The test `assert_no_personal_emails_in_marts` fails the build if a column like `email`, `phone`, `first_name` or `*_email` ever appears in a marts table. So a personal field can't reach a dashboard by accident.

## Who can see what

Metabase and any AI analytics tool connect with a read-only role that can only see the marts. On Postgres:

```sql
create role reporting_reader login password '...';
grant usage on schema marts to reporting_reader;
grant select on all tables in schema marts to reporting_reader;
alter default privileges in schema marts grant select on tables to reporting_reader;
-- No grants on raw, staging or intermediate.
```

On BigQuery the same idea applies: dataset-level access for the marts only, or column-level policy tags on the personal columns.

## When a customer asks to be forgotten

A deletion request removes the personal data but keeps the financial records. In Germany, invoices and accounting records must be kept for a legal retention period, so MRR history stays correct. Confirm the current rules with finance or legal.

1. **Log the request.** Add the customer ID and the date to `dbt/seeds/privacy_erasures.csv` (through a pull request, so there's a record of who did it and when).
2. **Hide it in dbt straight away.** `stg_stripe__customers` sets name, email and email domain to null for every customer on the list, and marks them `is_erased`. The next `dbt build` carries that through to every model. `assert_erased_customers_have_no_personal_data` checks it.
3. **Strip it from the raw layer.** `include/privacy/erase_raw.py` removes the personal fields from the raw JSON. The Stripe extract DAG runs it after every load, because a reload from Stripe would otherwise bring the fields back. Run it by hand with `make erase`.
4. **Delete it in the source tools.** The warehouse is a copy. The request must also be handled in Stripe and HubSpot, and in any exports or spreadsheets made from the data.

What stays: the customer ID, invoices, amounts, currency and plan history. These aren't personal on their own, and finance needs them.

What to check with legal: whether the company name from HubSpot counts as personal data for sole traders, and how long backups keep the old values.

## In the sample data

`cus_00061` is on the erasure list. It still counts in MRR (€199 in November) and keeps its 20 months of history, but has no email or email domain anywhere in the warehouse. Its name in `dim_customers` comes from the HubSpot company record, which is company data.

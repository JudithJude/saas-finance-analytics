-- Personal emails stay in staging. Anyone who can read the marts (Metabase, the AI tool,
-- finance) should never see one. Fails if a column that looks like an email or phone
-- number appears in any marts table.

select
    table_name,
    column_name
from information_schema.columns
where
    table_schema = '{{ generate_schema_name("marts", none) | trim }}'
    and (
        column_name in ('email', 'phone', 'first_name', 'last_name')
        or column_name like '%\_email'
        or column_name like '%\_phone'
    )

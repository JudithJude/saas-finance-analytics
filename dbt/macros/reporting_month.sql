{#
    The last month we report on: the current month, unless the `reporting_month` var is set
    (e.g. dbt build --vars '{reporting_month: 2026-10-01}' to rebuild October's close).
    A yearly plan paid up front must not create MRR for months that haven't happened yet.
#}
{% macro reporting_month() -%}
    {%- if var('reporting_month', none) -%}
        date_trunc('month', '{{ var("reporting_month") }}'::date)::date
    {%- else -%}
        date_trunc('month', current_date)::date
    {%- endif -%}
{%- endmacro %}

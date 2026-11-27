{# Whole months between two dates, e.g. a yearly invoice period = 12. #}
{% macro months_between(start_date, end_date) -%}
    (
        (extract(year from age({{ end_date }}, {{ start_date }})) * 12)
        + extract(month from age({{ end_date }}, {{ start_date }}))
    )::int
{%- endmacro %}

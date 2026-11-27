{# Stripe stores money in cents. Turn it into euros or dollars with two decimals. #}
{% macro cents_to_units(column_name) -%}
    round(({{ column_name }})::numeric / 100, 2)
{%- endmacro %}

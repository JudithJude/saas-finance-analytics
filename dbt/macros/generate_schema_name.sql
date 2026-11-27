{#
    In prod, models land in clean schemas: staging, intermediate, marts.
    Everywhere else (dev, CI), the schema is prefixed, e.g. dev_marts or ci_123_marts,
    so nobody overwrites the tables finance is looking at.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

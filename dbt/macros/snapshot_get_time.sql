{# Use a time-zone-aware timestamp in snapshots, to match updated_at. #}
{% macro postgres__snapshot_get_time() -%}
    now()
{%- endmacro %}

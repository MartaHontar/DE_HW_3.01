{% macro standardize_text(column_name) %}
    initcap(trim(lower({{ column_name }})))
{% endmacro %}
 
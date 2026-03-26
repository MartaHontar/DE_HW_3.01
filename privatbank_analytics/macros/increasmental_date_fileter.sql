{% macro incremental_date_filter(date_column) %}
    {% if is_incremental() %}
        {{ date_column }} > (select max({{ date_column }}) from {{ this }})
    {% else %}
        1 = 1
    {% endif %}
{% endmacro %}
 
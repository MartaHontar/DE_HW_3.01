{% macro classify_risk_level(score_column) %}
    case
        when {{ score_column }} >= 80 then 'High'
        when {{ score_column }} >= 50 then 'Medium'
        when {{ score_column }} >= 20 then 'Low'
        else 'Minimal'
    end
{% endmacro %}
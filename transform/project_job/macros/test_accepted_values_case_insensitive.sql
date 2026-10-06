{% test accepted_values_case_insensitive(model, column_name, values) %}

SELECT *
FROM {{ model }}
WHERE UPPER({{ column_name }}) NOT IN (
    {{ values | map('upper') | list | join(', ') | replace('[', '') | replace(']', '') }}
)
AND {{ column_name }} IS NOT NULL
AND {{ config.get('where', '1=1') }}

{% endtest %}
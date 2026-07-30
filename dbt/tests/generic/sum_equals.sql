{% test sum_equals(model, column_name, expected=100, tolerance=0.05, group_by=none) %}
-- Reusable: asserts that column_name sums to `expected` (optionally within each
-- group_by partition). `tolerance` absorbs the rounding of stored percentages;
-- size it to the row count (n rows rounded to 2 dp can drift up to n * 0.005).
with summed as (

    select
        {% if group_by %}{{ group_by | join(", ") }},{% endif %}
        sum({{ column_name }}) as column_total
    from {{ model }}
    {% if group_by %}group by {{ group_by | join(", ") }}{% endif %}

)

select *
from summed
where abs(column_total - {{ expected }}) > {{ tolerance }}
{% endtest %}

{% test sum_equals(model, column_name, expected=100, tolerance=0.05, group_by=none, per_row_tolerance=0.005) %}
-- Reusable: asserts that column_name sums to `expected` (optionally within each
-- group_by partition).
--
-- Percentages are stored rounded to 2 dp, so summing n of them drifts by up to
-- n * 0.005. A fixed tolerance therefore breaks as the data grows. We size the
-- tolerance to the actual row count of each group and treat the passed-in
-- `tolerance` as a floor:  effective = greatest(tolerance, row_count * 0.005).
-- This stays correct whether the mart has 27 rows or 27 million.
with summed as (

    select
        {% if group_by %}{{ group_by | join(", ") }},{% endif %}
        sum({{ column_name }}) as column_total,
        count(*) as row_count
    from {{ model }}
    {% if group_by %}group by {{ group_by | join(", ") }}{% endif %}

)

select *
from summed
where abs(column_total - {{ expected }})
    > greatest({{ tolerance }}, row_count * {{ per_row_tolerance }})
{% endtest %}

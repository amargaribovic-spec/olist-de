{#
  Returns a scalar timestamp used to filter an incremental model to only the
  rows that arrived since the last build:  where _loaded_at > incremental_watermark().

  On an incremental run it is the max _loaded_at already in the model; on the
  first / --full-refresh run it falls back to a floor date so every row passes.

  Emitted as a single inline expression so the surrounding SQL keeps the SAME
  shape whether or not is_incremental() is true — this keeps `sqlfluff lint`
  deterministic (a {% if %} block inside a WHERE clause lints differently
  depending on whether the target table exists).
#}
{% macro incremental_watermark(column='_loaded_at') -%}
    {%- if is_incremental() -%}
        (select coalesce(max({{ column }}), '2000-01-01'::timestamptz) from {{ this }})
    {%- else -%}
        '2000-01-01'::timestamptz
    {%- endif -%}
{%- endmacro %}

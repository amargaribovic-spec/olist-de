{#
  Trim a text column and turn "blank-ish" values into a real NULL:
  empty strings and common masked-null tokens (N/A, -, null, none, ?, ., ...).
  Comparison is case-insensitive. Use on optional/free-text columns in staging.
#}
{% macro clean_text(column) %}
    case
        when
            lower(trim({{ column }})) in (
                '', 'n/a', 'na', '#n/a', '-', '--', 'null', 'none', '?', '.', 'undefined'
            )
            then null
        else trim({{ column }})
    end
{% endmacro %}

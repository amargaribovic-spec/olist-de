{#
  Override dbt's default schema naming.
  Default dbt behaviour concatenates:  <target.schema>_<custom_schema>
  (e.g. dbt_amar_staging). We want the custom schema used AS-IS (staging, marts,
  intermediate). Models with no +schema fall back to the target schema.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

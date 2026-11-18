{#
  safe_yyyymmdd: parse 'YYYYMMDD' text to a date. Returns null for blanks, malformed
  values and impossible years (raw DOB data contains values like '02020816' and '33218262').
#}
{% macro safe_yyyymmdd(col) %}
    case
        when try_strptime(trim({{ col }}), '%Y%m%d') is null then null
        when year(try_strptime(trim({{ col }}), '%Y%m%d')) not between 1900 and year(current_date) + 1 then null
        else cast(try_strptime(trim({{ col }}), '%Y%m%d') as date)
    end
{% endmacro %}

{#
  safe_mdy: parse 'MM/DD/YYYY' text to a date, same rules.
#}
{% macro safe_mdy(col) %}
    case
        when try_strptime(trim({{ col }}), '%m/%d/%Y') is null then null
        when year(try_strptime(trim({{ col }}), '%m/%d/%Y')) not between 1900 and year(current_date) + 1 then null
        else cast(try_strptime(trim({{ col }}), '%m/%d/%Y') as date)
    end
{% endmacro %}

{#
  BBL helpers.

  clean_bbl: PLUTO and some other sources publish BBL as a number, sometimes with a
  decimal tail ("3012340056.00000000"). Normalize to a 10-character zero-padded string.

  bbl_from_parts: build a BBL from borough code (1 digit), block (5) and lot (4),
  for datasets that publish the parts separately.
#}

{% macro clean_bbl(col) %}
    case
        when {{ col }} is null or trim({{ col }}) = '' then null
        else lpad(cast(try_cast(try_cast(trim({{ col }}) as double) as bigint) as varchar), 10, '0')
    end
{% endmacro %}

{% macro bbl_from_parts(borough_code, block, lot) %}
    case
        when try_cast({{ borough_code }} as integer) is null
          or try_cast({{ block }} as integer) is null
          or try_cast({{ lot }} as integer) is null
        then null
        else cast(try_cast({{ borough_code }} as integer) as varchar)
          || lpad(cast(try_cast({{ block }} as integer) as varchar), 5, '0')
          || lpad(cast(try_cast({{ lot }} as integer) as varchar), 4, '0')
    end
{% endmacro %}

{#
  borough_code: map the different borough spellings used across datasets to 1-5.
#}
{% macro borough_code(col) %}
    case upper(trim({{ col }}))
        when '1' then '1' when 'MN' then '1' when 'MANHATTAN' then '1'
        when '2' then '2' when 'BX' then '2' when 'BRONX' then '2'
        when '3' then '3' when 'BK' then '3' when 'BROOKLYN' then '3'
        when '4' then '4' when 'QN' then '4' when 'QUEENS' then '4'
        when '5' then '5' when 'SI' then '5' when 'STATEN ISLAND' then '5'
        else null
    end
{% endmacro %}

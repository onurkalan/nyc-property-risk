-- Version 1 loads a single borough. Lots from any other borough mean a loader filter is wrong.

select bbl, borough_code
from {{ ref('dim_property') }}
where borough_code <> '{{ var("borough_code") }}'

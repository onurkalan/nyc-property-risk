-- The 10-digit BBL must agree with the separate borough, block and lot columns.
-- Any rows returned here are failures.

select
    bbl,
    borough_code,
    block,
    lot
from {{ ref('stg_pluto') }}
where bbl <> {{ bbl_from_parts('borough_code', 'block', 'lot') }}

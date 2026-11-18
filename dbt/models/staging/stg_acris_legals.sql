-- One row per (document, lot) pair from ACRIS legals. A single deed or mortgage can
-- cover several lots, and a lot appears on many documents over time.

with source as (

    select * from {{ source('raw', 'acris_legals') }}

)

select
    nullif(trim(document_id), '')                                   as document_id,
    {{ bbl_from_parts('borough', 'block', 'lot') }}                 as bbl,
    nullif(upper(trim(property_type)), '')                          as property_type,
    upper(trim(partial_lot))                                        as partial_lot_code,
    upper(trim(easement)) = 'Y'                                     as is_easement,
    upper(trim(air_rights)) = 'Y'                                   as is_air_rights,
    nullif(upper(trim(unit)), '')                                   as unit,
    nullif(upper(trim(street_number)), '')                          as house_number,
    nullif(upper(trim(street_name)), '')                            as street
from source
where nullif(trim(document_id), '') is not null

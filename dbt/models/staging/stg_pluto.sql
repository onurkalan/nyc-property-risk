-- One row per tax lot from City Planning's PLUTO dataset.
-- Column names follow the NYC Open Data field names; confirm with scripts/profile_raw.py.

with source as (

    select * from {{ source('raw', 'pluto') }}

),

typed as (

    select
        {{ clean_bbl('bbl') }}                                  as bbl,
        {{ borough_code('borough') }}                           as borough_code,
        try_cast(block as integer)                              as block,
        try_cast(lot as integer)                                as lot,

        nullif(upper(trim(address)), '')                        as address,
        nullif(trim(zipcode), '')                               as zip_code,
        nullif(upper(trim(zonedist1)), '')                      as zoning_district,

        nullif(upper(trim(bldgclass)), '')                      as building_class,
        nullif(trim(landuse), '')                               as land_use_code,
        nullif(upper(trim(ownertype)), '')                      as owner_type_code,
        nullif(upper(trim(ownername)), '')                      as owner_name,

        try_cast(lotarea as double)                             as lot_area_sqft,
        try_cast(bldgarea as double)                            as building_area_sqft,
        try_cast(numbldgs as integer)                           as num_buildings,
        try_cast(numfloors as double)                           as num_floors,
        try_cast(unitsres as integer)                           as residential_units,
        try_cast(unitstotal as integer)                         as total_units,
        nullif(try_cast(yearbuilt as integer), 0)               as year_built,
        nullif(try_cast(yearalter1 as integer), 0)              as year_altered_1,

        try_cast(assessland as double)                          as assessed_land_value,
        try_cast(assesstot as double)                           as assessed_total_value,
        try_cast(exempttot as double)                           as exempt_total_value,

        try_cast(latitude as double)                            as latitude,
        try_cast(longitude as double)                           as longitude

    from source

)

select *
from typed
where bbl is not null

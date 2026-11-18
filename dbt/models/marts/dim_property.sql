-- Property spine: one row per tax lot, with the attributes every report starts from.
-- Permits, violations, sales and ownership will all join to this table on bbl.

with lots as (

    select * from {{ ref('stg_pluto') }}

),

classified as (

    select
        *,

        -- Building class prefix: A = one-family, B = two-family, C = walk-up apartments,
        -- D = elevator apartments, R = condominiums, S = mixed residential/commercial.
        left(building_class, 1) as building_class_group,

        case
            when residential_units is null or residential_units = 0 then 'non_residential'
            when residential_units between 1 and 4 then '1_4_family'
            when residential_units between 5 and 20 then 'small_multifamily'
            when residential_units between 21 and 100 then 'mid_multifamily'
            else 'large_multifamily'
        end as residential_size_band,

        case
            when year_built is null then null
            else extract(year from current_date) - year_built
        end as building_age_years

    from lots

)

select
    bbl,
    borough_code,
    block,
    lot,
    address,
    zip_code,
    zoning_district,
    building_class,
    building_class_group,
    land_use_code,
    owner_type_code,
    owner_name,
    lot_area_sqft,
    building_area_sqft,
    num_buildings,
    num_floors,
    residential_units,
    total_units,
    residential_size_band,
    residential_size_band in ('1_4_family', 'small_multifamily') as is_v1_target_type,
    year_built,
    year_altered_1,
    building_age_years,
    assessed_land_value,
    assessed_total_value,
    exempt_total_value,
    latitude,
    longitude
from classified

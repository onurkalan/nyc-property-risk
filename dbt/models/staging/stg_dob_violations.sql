-- One row per Buildings Department (BIS) violation.
-- Status and risk flags are parsed from the violation_category prefix, e.g.
--   'V-DOB VIOLATION - ACTIVE'                -> open
--   'V*-DOB VIOLATION - DISMISSED'            -> closed ('*' = closed)
--   'VW-VIOLATION WORK WITHOUT PERMIT - ACTIVE' -> open, work without permit
--   'VH-VIOLATION HAZARDOUS - ACTIVE'         -> open, hazardous
-- Verified against all Brooklyn rows on 2026-11-17 (see docs/BUILD_LOG.md).

with source as (

    select * from {{ source('raw', 'dob_violations') }}

),

typed as (

    select
        nullif(trim(isn_dob_bis_viol), '')                          as violation_id,
        nullif(trim(number), '')                                    as violation_number_full,
        {{ bbl_from_parts('boro', 'block', 'lot') }}                as bbl,
        nullif(trim(bin), '')                                       as bin,

        nullif(upper(trim(house_number)), '')                       as house_number,
        nullif(upper(trim(street)), '')                             as street,

        {{ safe_yyyymmdd('issue_date') }}                           as issue_date,
        {{ safe_yyyymmdd('disposition_date') }}                     as disposition_date,

        nullif(upper(trim(violation_type_code)), '')                as violation_type_code,
        nullif(trim(violation_type), '')                            as violation_type,
        nullif(trim(violation_category), '')                        as violation_category,
        nullif(trim(description), '')                               as description,
        nullif(trim(disposition_comments), '')                      as disposition_comments,
        nullif(trim(ecb_number), '')                                as ecb_number,
        nullif(trim(device_number), '')                             as device_number,

        -- prefix before the first '-', e.g. 'VW*'
        split_part(trim(violation_category), '-', 1)                as category_prefix

    from source

)

select
    * exclude (category_prefix),
    category_prefix is not null and category_prefix not like '%*%' as is_open,
    coalesce(category_prefix like '%W%', false)                     as is_work_without_permit,
    coalesce(category_prefix like '%H%', false)                     as is_hazardous
from typed
where violation_id is not null

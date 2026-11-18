-- One row per DOB NOW work permit, sequence (renewal) number and work type.
-- A single permit number can cover several work types (verified 2026-11-18).
-- The applicant on a permit is the licensed contractor doing the work; applicant_license
-- is the key for contractor vetting later.
-- BBLs on condo buildings may be billing lots (lot 7501-7599) rather than unit lots.

with source as (

    select * from {{ source('raw', 'dobnow_approved_permits') }}

),

typed as (

    select
        nullif(trim(work_permit), '')                               as work_permit,
        try_cast(sequence_number as integer)                        as sequence_number,
        nullif(trim(job_filing_number), '')                         as job_filing_number,
        nullif(trim(tracking_number), '')                           as tracking_number,

        {{ clean_bbl('bbl') }}                                      as bbl,
        nullif(trim(bin), '')                                       as bin,
        nullif(upper(trim(house_no)), '')                           as house_number,
        nullif(upper(trim(street_name)), '')                        as street,

        nullif(trim(filing_reason), '')                             as filing_reason,
        nullif(trim(work_type), '')                                 as work_type,
        nullif(trim(work_on_floor), '')                             as work_on_floor,
        nullif(trim(job_description), '')                           as job_description,
        try_cast(estimated_job_costs as double)                     as estimated_job_cost,

        nullif(trim(permit_status), '')                             as permit_status,
        trim(permit_status) = 'Permit Issued'                       as is_active,

        cast(try_cast(approved_date as timestamp) as date)          as approved_date,
        cast(try_cast(issued_date as timestamp) as date)            as issued_date,
        cast(try_cast(expired_date as timestamp) as date)           as expired_date,

        nullif(upper(trim(permittee_s_license_type)), '')           as contractor_license_type,
        nullif(trim(applicant_license), '')                         as contractor_license_number,
        nullif(upper(trim(applicant_business_name)), '')            as contractor_business_name,
        nullif(upper(trim(concat_ws(' ', applicant_first_name, applicant_last_name))), '')
                                                                    as contractor_person_name,

        nullif(upper(trim(owner_business_name)), '')                as owner_business_name,
        nullif(upper(trim(owner_name)), '')                         as owner_name

    from source

)

select *
from typed
where work_permit is not null

-- One row per HPD multiple-dwelling registration. Buildings with 3+ units must register
-- owners and managing agents annually; contacts live in stg_hpd_registration_contacts.
-- Grain: registration + building. A few registration IDs cover two buildings in the source.

with source as (

    select * from {{ source('raw', 'hpd_registrations') }}

)

select
    nullif(trim(registrationid), '')                                as hpd_registration_id,
    nullif(trim(buildingid), '')                                    as hpd_building_id,
    {{ bbl_from_parts('boroid', 'block', 'lot') }}                  as bbl,
    nullif(trim(bin), '')                                           as bin,
    nullif(upper(trim(housenumber)), '')                            as house_number,
    nullif(upper(trim(streetname)), '')                             as street,
    nullif(trim(zip), '')                                           as zip_code,
    cast(try_cast(lastregistrationdate as timestamp) as date)       as last_registration_date,
    cast(try_cast(registrationenddate as timestamp) as date)        as registration_end_date
from source
where nullif(trim(registrationid), '') is not null

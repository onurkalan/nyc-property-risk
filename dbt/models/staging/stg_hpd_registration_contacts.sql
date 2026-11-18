-- One row per contact (owner, officer, agent, site manager) on an HPD registration.
-- Source is citywide; filter to Brooklyn by joining to stg_hpd_registrations.
-- registrationcontactid is NOT unique in the source (~0.2% reused, sometimes for different
-- people), so rows that are identical after cleaning are removed and contact_row_key
-- (hash of the cleaned row) is the key.

with source as (

    select * from {{ source('raw', 'hpd_registration_contacts') }}

),

cleaned as (

select distinct
    nullif(trim(registrationcontactid), '')                         as registration_contact_id,
    nullif(trim(registrationid), '')                                as hpd_registration_id,
    nullif(trim(type), '')                                          as contact_type,
    trim(type) in ('CorporateOwner', 'IndividualOwner', 'JointOwner') as is_owner,
    nullif(upper(trim(contactdescription)), '')                     as contact_description,
    nullif(nullif(upper(trim(corporationname)), ''), 'N/A')         as corporation_name,
    nullif(upper(trim(title)), '')                                  as title,
    nullif(upper(trim(firstname)), '')                              as first_name,
    nullif(upper(trim(lastname)), '')                               as last_name,
    nullif(upper(trim(concat_ws(' ', businesshousenumber, businessstreetname))), '')
                                                                    as business_address,
    nullif(upper(trim(businesscity)), '')                           as business_city,
    nullif(upper(trim(businessstate)), '')                          as business_state,
    nullif(trim(businesszip), '')                                   as business_zip
from source
where nullif(trim(registrationcontactid), '') is not null

)

select
    md5(cast(cleaned as varchar)) as contact_row_key,
    *
from cleaned

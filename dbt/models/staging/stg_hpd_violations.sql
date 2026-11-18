-- One row per Housing Preservation and Development (HPD) housing code violation.
-- class: A non-hazardous, B hazardous, C immediately hazardous, I information order
-- (administrative, not a physical condition). Status comes from violationstatus (Open/Close).

with source as (

    select * from {{ source('raw', 'hpd_violations') }}

)

select
    nullif(trim(violationid), '')                                   as violation_id,
    {{ clean_bbl('bbl') }}                                          as bbl,
    nullif(trim(bin), '')                                           as bin,
    nullif(nullif(trim(buildingid), ''), '0')                       as hpd_building_id,
    nullif(nullif(trim(registrationid), ''), '0')                   as hpd_registration_id,

    nullif(upper(trim(housenumber)), '')                            as house_number,
    nullif(upper(trim(streetname)), '')                             as street,
    nullif(upper(trim(apartment)), '')                              as apartment,

    upper(nullif(trim(class), ''))                                  as violation_class,
    case upper(trim(class))
        when 'C' then 'high'
        when 'B' then 'medium'
        when 'A' then 'low'
        when 'I' then 'info'
        else 'unknown'
    end                                                             as severity_level,
    trim(violationstatus) = 'Open'                                  as is_open,
    upper(trim(rentimpairing)) = 'Y'                                as is_rent_impairing,

    nullif(trim(currentstatus), '')                                 as current_status,
    nullif(trim(novdescription), '')                                as description,
    nullif(trim(ordernumber), '')                                   as order_number,

    cast(try_cast(inspectiondate as timestamp) as date)             as inspection_date,
    cast(try_cast(novissueddate as timestamp) as date)              as issued_date,
    cast(try_cast(currentstatusdate as timestamp) as date)          as current_status_date,
    cast(try_cast(certifieddate as timestamp) as date)              as certified_date

from source
where nullif(trim(violationid), '') is not null

-- One row per ECB violation record issued by the Buildings Department.
-- ECB (now OATH) violations carry civil penalties; unpaid balances can become liens.
--
-- Severity uses two schemes in the source:
--   older: 'Hazardous' / 'Non-Hazardous'
--   newer: 'CLASS - 1' (immediately hazardous), 'CLASS - 2' (major), 'CLASS - 3' (lesser)
-- severity_level maps both to high / medium / low. 'Non-Hazardous' is mapped to medium
-- because the old scheme does not separate major from lesser.

with source as (

    select * from {{ source('raw', 'ecb_violations') }}

),

typed as (

    select
        nullif(trim(isn_dob_bis_extract), '')                       as ecb_record_id,
        nullif(trim(ecb_violation_number), '')                      as ecb_violation_number,
        nullif(trim(dob_violation_number), '')                      as dob_violation_number,

        {{ bbl_from_parts('boro', 'block', 'lot') }}                as bbl,
        nullif(trim(bin), '')                                       as bin,

        {{ safe_yyyymmdd('issue_date') }}                           as issue_date,
        {{ safe_yyyymmdd('served_date') }}                          as served_date,
        {{ safe_yyyymmdd('hearing_date') }}                         as hearing_date,

        upper(nullif(trim(ecb_violation_status), ''))               as ecb_status,
        upper(nullif(trim(ecb_violation_status), '')) = 'ACTIVE'    as is_open,

        nullif(trim(severity), '')                                  as severity_raw,
        case upper(trim(severity))
            when 'CLASS - 1'     then 'high'
            when 'HAZARDOUS'     then 'high'
            when 'CLASS - 2'     then 'medium'
            when 'NON-HAZARDOUS' then 'medium'
            when 'CLASS - 3'     then 'low'
            else 'unknown'
        end                                                         as severity_level,

        nullif(trim(violation_type), '')                            as violation_type,
        nullif(trim(violation_description), '')                     as violation_description,
        nullif(trim(infraction_code1), '')                          as infraction_code,
        nullif(trim(section_law_description1), '')                  as infraction_description,
        nullif(trim(aggravated_level), '')                          as aggravated_level,
        nullif(trim(hearing_status), '')                            as hearing_status,
        nullif(trim(certification_status), '')                      as certification_status,

        nullif(upper(trim(respondent_name)), '')                    as respondent_name,

        -- source column is misspelled 'penality_imposed'
        coalesce(try_cast(penality_imposed as double), 0)           as penalty_imposed,
        coalesce(try_cast(amount_paid as double), 0)                as amount_paid,
        coalesce(try_cast(balance_due as double), 0)                as balance_due

    from source

)

select *
from typed
where ecb_record_id is not null

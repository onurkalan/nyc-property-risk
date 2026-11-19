-- Grain check for stg_hpd_registrations: one row per registration and building.
select hpd_registration_id, hpd_building_id, count(*) as n
from {{ ref('stg_hpd_registrations') }}
group by 1, 2
having count(*) > 1

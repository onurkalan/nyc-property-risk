-- Grain check: one row per permit, sequence (renewal) number and work type.
-- One permit number can cover several work types (e.g. General Construction + Foundation + Structural).
-- A small residual of true duplicates exists in the source; warn rather than fail.
{{ config(severity='warn', warn_if='>0', error_if='>500') }}
select work_permit, sequence_number, work_type, count(*) as n
from {{ ref('stg_dobnow_approved_permits') }}
group by 1, 2, 3
having count(*) > 1

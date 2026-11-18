-- One row per ACRIS recorded document (deed, mortgage, satisfaction, lien, ...).
-- Which lots a document covers is in stg_acris_legals; document classes come from the
-- acris_document_types seed (city's ACRIS Document Control Codes, dataset 7isb-wh4c).

with source as (

    select * from {{ source('raw', 'acris_master') }}

)

select
    nullif(trim(document_id), '')                                   as document_id,
    nullif(trim(crfn), '')                                          as crfn,
    upper(nullif(trim(doc_type), ''))                               as doc_type,
    cast(try_cast(document_date as timestamp) as date)              as document_date,
    cast(try_cast(recorded_datetime as timestamp) as date)          as recorded_date,
    try_cast(document_amt as double)                                as document_amount,
    try_cast(percent_trans as double)                               as percent_transferred,
    cast(try_cast(modified_date as timestamp) as date)              as modified_date
from source
where nullif(trim(document_id), '') is not null

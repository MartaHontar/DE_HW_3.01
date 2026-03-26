with source as (
    select * from "privatbank"."main"."raw_loan_applications"
),

cleaned as (
    select
        application_id,
        customer_id,
        cast(application_date as date)             as application_date,
        
    initcap(trim(lower(loan_type)))
        as loan_type,
        cast(requested_amount as numeric(18,2))    as requested_amount,
        cast(approved_amount as numeric(18,2))     as approved_amount,
        cast(interest_rate as numeric(5,2))        as interest_rate,
        cast(term_months as integer)               as term_months,
        
    initcap(trim(lower(status)))
           as status,
        
    initcap(trim(lower(rejection_reason)))
 as rejection_reason,
        cast(disbursement_date as date)            as disbursement_date
    from source
)

select * from cleaned
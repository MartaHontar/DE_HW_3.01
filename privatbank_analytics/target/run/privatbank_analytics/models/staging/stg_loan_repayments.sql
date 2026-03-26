
  
  create view "privatbank"."main"."stg_loan_repayments__dbt_tmp" as (
    with source as (
    select * from "privatbank"."main"."raw_loan_repayments"
),

cleaned as (
    select
        repayment_id,
        application_id,
        cast(payment_date as date)                as payment_date,
        cast(scheduled_date as date)              as scheduled_date,
        cast(amount_paid as numeric(18,2))        as amount_paid,
        cast(principal_paid as numeric(18,2))     as principal_paid,
        cast(interest_paid as numeric(18,2))      as interest_paid,
        cast(outstanding_balance as numeric(18,2)) as outstanding_balance,
        cast(is_overdue as boolean)               as is_overdue,
        cast(days_overdue as integer)             as days_overdue
    from source
)

select * from cleaned
  );

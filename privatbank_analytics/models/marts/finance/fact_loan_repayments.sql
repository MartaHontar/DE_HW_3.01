{{
    config(
        materialized='incremental',
        unique_key='repayment_id',
        incremental_strategy='delete+insert',
        on_schema_change='sync_all_columns'
    )
}}



with repayments as (
    select * from {{ ref('stg_loan_repayments') }}
    where {{ incremental_date_filter('payment_date') }}
),

loans as (
    select
        application_id,
        customer_id,
        loan_type,
        approved_amount,
        interest_rate,
        term_months,
        status          as loan_status,
        disbursement_date
    from {{ ref('stg_loan_applications') }}
),

customers as (
    select
        customer_id,
        first_name || ' ' || last_name  as customer_name,
        customer_segment,
        credit_score
    from {{ ref('stg_customers') }}
),

enriched as (
    select
        r.repayment_id,
        r.application_id,
        l.customer_id,
        c.customer_name,
        c.customer_segment,
        c.credit_score,

        l.loan_type,
        l.approved_amount,
        l.interest_rate,
        l.term_months,
        l.loan_status,
        l.disbursement_date,

        r.payment_date,
        r.scheduled_date,
        r.amount_paid,
        r.principal_paid,
        r.interest_paid,
        r.outstanding_balance,
        r.is_overdue,
        r.days_overdue,

        -- how many days early (negative) or late (positive)
        r.payment_date - r.scheduled_date           as days_early_or_late,

        -- overdue severity bucket
        case
            when r.days_overdue = 0    then 'On Time'
            when r.days_overdue <= 30  then 'Slightly Late'
            when r.days_overdue <= 90  then 'Moderately Late'
            else 'Severely Late'
        end                                         as overdue_bucket,

        -- cumulative amount paid per loan
        sum(r.amount_paid) over (
            partition by r.application_id
            order by r.payment_date
            rows between unbounded preceding and current row
        )                                           as cumulative_paid,

        -- which payment number is this (1st, 2nd, 3rd...)
        row_number() over (
            partition by r.application_id
            order by r.payment_date
        )                                           as payment_number

    from repayments r
    left join loans     l on r.application_id = l.application_id
    left join customers c on l.customer_id    = c.customer_id
)

select * from enriched
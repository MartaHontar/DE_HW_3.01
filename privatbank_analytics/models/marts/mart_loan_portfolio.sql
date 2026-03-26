{{
    config(materialized='table')
}}

/*
  Grain: one row per loan application.
  Summarises repayment performance per loan.
  Business questions:
    - How many loans are non-performing?
    - Where is the largest credit exposure?
    - Which loan types have the worst repayment rates?
  Window functions:
    - exposure_rank: loans ranked by outstanding balance (most exposed first)
    - overdue_rank_in_type: worst payers ranked within each loan type
*/

with loans as (
    select * from {{ ref('stg_loan_applications') }}
),

customers as (
    select
        customer_id,
        first_name || ' ' || last_name  as customer_name,
        customer_segment,
        credit_score,
        city,
        region
    from {{ ref('stg_customers') }}
),

repayment_stats as (
    select
        application_id,
        count(*)                                        as total_payments_made,
        count(*) filter (where is_overdue)              as overdue_payments,
        sum(amount_paid)                                as total_paid,
        sum(principal_paid)                             as total_principal_paid,
        sum(interest_paid)                              as total_interest_paid,
        min(outstanding_balance)                        as current_outstanding_balance,
        max(days_overdue)                               as max_days_overdue,
        max(payment_date)                               as last_payment_date,
        max(payment_number)                             as payments_made_count
    from {{ ref('fact_loan_repayments') }}
    group by application_id
),

assembled as (
    select
        l.application_id,
        l.customer_id,
        c.customer_name,
        c.customer_segment,
        c.credit_score,
        c.city,
        c.region,

        l.loan_type,
        l.application_date,
        l.approved_amount,
        l.interest_rate,
        l.term_months,
        l.status                                        as loan_status,
        l.disbursement_date,

        coalesce(r.total_payments_made, 0)              as total_payments_made,
        coalesce(r.overdue_payments, 0)                 as overdue_payments,
        coalesce(r.total_paid, 0)                       as total_paid,
        coalesce(r.total_principal_paid, 0)             as total_principal_paid,
        coalesce(r.total_interest_paid, 0)              as total_interest_paid,
        coalesce(r.current_outstanding_balance,
                 l.approved_amount)                     as current_outstanding_balance,
        coalesce(r.max_days_overdue, 0)                 as max_days_overdue,
        r.last_payment_date,

        -- NPL classification
        case
            when l.status != 'Approved'                     then 'Not Applicable'
            when coalesce(r.max_days_overdue, 0) > 90       then 'Non-Performing'
            when coalesce(r.max_days_overdue, 0) > 30       then 'Watchlist'
            else 'Performing'
        end                                             as npl_status,

        -- % of loan repaid so far
        round(
            coalesce(r.total_principal_paid, 0)
            / nullif(l.approved_amount, 0) * 100, 1
        )                                               as pct_repaid,

        -- rank by outstanding balance — most exposed loan first
        rank() over (
            order by coalesce(r.current_outstanding_balance,
                              l.approved_amount) desc
        )                                               as exposure_rank,

        -- rank worst payers within each loan type
        rank() over (
            partition by l.loan_type
            order by coalesce(r.overdue_payments, 0) desc
        )                                               as overdue_rank_in_type

    from loans          l
    left join customers      c on l.customer_id    = c.customer_id
    left join repayment_stats r on l.application_id = r.application_id
)

select * from assembled
order by exposure_rank

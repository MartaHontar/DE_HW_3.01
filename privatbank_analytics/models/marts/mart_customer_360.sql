{{
    config(materialized='table')
}}

/*
  Grain: one row per customer.
  Combines transaction activity, fraud exposure, and loan data
  into a single customer profile.
  Business questions:
    - Who are the top customers by lifetime spend?
    - Which customers have the most fraud exposure?
    - Which customers are most at risk of churn (inactive)?
  Window functions:
    - spend_rank: rank customers by lifetime spend overall
    - spend_rank_in_segment: rank within their segment
*/

with customers as (
    select * from {{ ref('stg_customers') }}
),

accounts as (
    select
        customer_id,
        count(*)                                        as total_accounts,
        sum(current_balance)                            as total_balance_uah,
        sum(credit_limit)                               as total_credit_limit
    from {{ ref('stg_accounts') }}
    group by customer_id
),

transactions as (
    select
        customer_id,
        count(*)                                        as total_transactions,
        sum(amount_uah) filter (
            where transaction_direction = 'debit'
        )                                               as lifetime_spend_uah,
        max(transaction_date)                           as last_transaction_date,
        count(*) filter (where is_flagged)              as flagged_txn_count
    from {{ ref('fact_transactions') }}
    group by customer_id
),

fraud as (
    select
        customer_id,
        count(*)                                        as total_fraud_alerts,
        count(*) filter (where is_confirmed_fraud)      as confirmed_fraud_count,
        sum(loss_amount)                                as total_fraud_loss_uah,
        max(risk_score)                                 as max_risk_score
    from {{ ref('fact_fraud_events') }}
    group by customer_id
),

loans as (
    select
        customer_id,
        count(*) filter (where loan_status = 'Approved') as approved_loans,
        sum(approved_amount) filter (
            where loan_status = 'Approved'
        )                                               as total_loan_amount_uah
    from {{ ref('fact_loan_repayments') }}
    group by customer_id
),

assembled as (
    select
        c.customer_id,
        c.first_name || ' ' || c.last_name              as customer_name,
        c.customer_segment,
        c.city,
        c.region,
        c.credit_score,
        c.is_active,
        c.age_years,
        c.registration_date,
        c.days_since_registration,

        -- account metrics
        coalesce(a.total_accounts, 0)                   as total_accounts,
        coalesce(a.total_balance_uah, 0)                as total_balance_uah,
        coalesce(a.total_credit_limit, 0)               as total_credit_limit,

        -- transaction metrics
        coalesce(t.total_transactions, 0)               as total_transactions,
        coalesce(t.lifetime_spend_uah, 0)               as lifetime_spend_uah,
        t.last_transaction_date,
        current_date - t.last_transaction_date          as days_since_last_txn,
        coalesce(t.flagged_txn_count, 0)                as flagged_txn_count,

        -- fraud metrics
        coalesce(f.total_fraud_alerts, 0)               as total_fraud_alerts,
        coalesce(f.confirmed_fraud_count, 0)            as confirmed_fraud_count,
        coalesce(f.total_fraud_loss_uah, 0)             as total_fraud_loss_uah,
        coalesce(f.max_risk_score, 0)                   as max_risk_score,

        -- loan metrics
        coalesce(l.approved_loans, 0)                   as approved_loans,
        coalesce(l.total_loan_amount_uah, 0)            as total_loan_amount_uah,

        -- churn risk label based on days inactive
        case
            when current_date - t.last_transaction_date > 180 then 'High'
            when current_date - t.last_transaction_date > 90  then 'Medium'
            when current_date - t.last_transaction_date > 30  then 'Low'
            else 'Active'
        end                                             as churn_risk,

        -- rank all customers by lifetime spend
        rank() over (
            order by coalesce(t.lifetime_spend_uah, 0) desc
        )                                               as spend_rank,

        -- rank within segment
        rank() over (
            partition by c.customer_segment
            order by coalesce(t.lifetime_spend_uah, 0) desc
        )                                               as spend_rank_in_segment

    from customers      c
    left join accounts  a on c.customer_id = a.customer_id
    left join transactions t on c.customer_id = t.customer_id
    left join fraud     f on c.customer_id = f.customer_id
    left join loans     l on c.customer_id = l.customer_id
)

select * from assembled
order by spend_rank

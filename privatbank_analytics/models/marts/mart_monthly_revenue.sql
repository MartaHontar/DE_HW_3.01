{{
    config(materialized='table')
}}

/*
  Grain: one row per calendar month.
  Combines transaction volumes, interest income, and fraud losses
  into a monthly financial summary.
  Business questions:
    - What is the monthly revenue trend?
    - How much do fraud losses cost relative to interest income?
    - Which months had the highest transaction activity?
  Window functions:
    - spend_mom_pct_change: month-over-month spend change via lag()
    - rolling_3m_avg_spend_uah: 3-month rolling average via avg() over window
    - cumulative_interest_income_uah: running total interest collected
*/

with monthly_txns as (
    select
        date_trunc('month', transaction_date)           as month,
        count(*)                                        as transaction_count,
        sum(amount_uah) filter (
            where transaction_direction = 'debit'
        )                                               as total_spend_uah,
        sum(amount_uah) filter (
            where transaction_direction = 'credit'
        )                                               as total_inflow_uah,
        count(distinct customer_id)                     as active_customers,
        count(*) filter (where is_flagged)              as flagged_transactions
    from {{ ref('fact_transactions') }}
    where status = 'Completed'
    group by 1
),

monthly_interest as (
    select
        date_trunc('month', payment_date)               as month,
        sum(interest_paid)                              as interest_income_uah,
        count(distinct application_id)                  as loans_serviced,
        count(*) filter (where is_overdue)              as overdue_payments
    from {{ ref('fact_loan_repayments') }}
    group by 1
),

monthly_fraud as (
    select
        date_trunc('month', alert_date)                 as month,
        sum(loss_amount) filter (
            where is_confirmed_fraud
        )                                               as confirmed_fraud_losses_uah,
        count(*) filter (where is_confirmed_fraud)      as confirmed_fraud_count,
        count(*)                                        as total_fraud_alerts
    from {{ ref('stg_fraud_alerts') }}
    group by 1
),

assembled as (
    select
        coalesce(t.month, i.month, f.month)             as month,

        coalesce(t.transaction_count, 0)                as transaction_count,
        coalesce(t.total_spend_uah, 0)                  as total_spend_uah,
        coalesce(t.total_inflow_uah, 0)                 as total_inflow_uah,
        coalesce(t.active_customers, 0)                 as active_customers,
        coalesce(t.flagged_transactions, 0)             as flagged_transactions,

        coalesce(i.interest_income_uah, 0)              as interest_income_uah,
        coalesce(i.loans_serviced, 0)                   as loans_serviced,
        coalesce(i.overdue_payments, 0)                 as overdue_payments,

        coalesce(f.confirmed_fraud_losses_uah, 0)       as confirmed_fraud_losses_uah,
        coalesce(f.confirmed_fraud_count, 0)            as confirmed_fraud_count,
        coalesce(f.total_fraud_alerts, 0)               as total_fraud_alerts,

        -- net revenue: interest income minus fraud losses
        coalesce(i.interest_income_uah, 0)
        - coalesce(f.confirmed_fraud_losses_uah, 0)     as net_revenue_uah,

        -- fraud losses as % of interest income
        round(
            coalesce(f.confirmed_fraud_losses_uah, 0)
            / nullif(coalesce(i.interest_income_uah, 0), 0) * 100, 2
        )                                               as fraud_cost_pct_of_revenue

    from monthly_txns   t
    full outer join monthly_interest i on t.month = i.month
    full outer join monthly_fraud    f on t.month = f.month
),

with_trends as (
    select
        *,

        -- month-over-month spend % change
        round(
            (total_spend_uah - lag(total_spend_uah) over (order by month))
            / nullif(lag(total_spend_uah) over (order by month), 0) * 100, 2
        )                                               as spend_mom_pct_change,

        -- 3-month rolling average spend
        avg(total_spend_uah) over (
            order by month
            rows between 2 preceding and current row
        )                                               as rolling_3m_avg_spend_uah,

        -- cumulative interest income collected to date
        sum(interest_income_uah) over (
            order by month
            rows between unbounded preceding and current row
        )                                               as cumulative_interest_income_uah

    from assembled
)

select * from with_trends
order by month

{{
    config(
        materialized='incremental',
        unique_key='event_id',
        incremental_strategy='delete+insert',
        incremental_predicates=["alert_date >= current_date - interval '90 days'"]
    )
}}


with fraud as (
    select * from {{ ref('stg_fraud_alerts') }}
    where {{ incremental_date_filter('alert_date') }}
),

transactions as (
    select
        transaction_id,
        account_id,
        transaction_date,
        amount_uah,
        merchant_category,
        channel,
        city
    from {{ ref('fact_transactions') }}
),

accounts as (
    select account_id, customer_id
    from {{ ref('stg_accounts') }}
),

customers as (
    select
        customer_id,
        first_name || ' ' || last_name  as customer_name,
        customer_segment,
        credit_score
    from {{ ref('stg_customers') }}
),

joined as (
    select
        {{ generate_surrogate_key(['f.alert_id', 'f.transaction_id']) }} as event_id,

        f.alert_id,
        f.transaction_id,
        f.account_id,
        a.customer_id,
        c.customer_name,
        c.customer_segment,
        c.credit_score,

        f.alert_date,
        f.alert_type,
        f.risk_score,
        {{ classify_risk_level('f.risk_score') }}   as risk_level,
        f.investigation_status,
        f.is_confirmed_fraud,
        f.fraud_type,
        f.loss_amount,

        t.transaction_date,
        t.amount_uah                                as transaction_amount_uah,
        t.merchant_category,
        t.channel,

        -- days between transaction and fraud alert
        f.alert_date - t.transaction_date           as days_to_alert,

        -- how much does this transaction deviate from the account's average
        t.amount_uah - avg(t.amount_uah) over (
            partition by f.account_id
        )                                           as amount_vs_account_avg

    from fraud f
    left join transactions t on f.transaction_id = t.transaction_id
    left join accounts     a on f.account_id     = a.account_id
    left join customers    c on a.customer_id    = c.customer_id
)

select * from joined
{{
    config(
        materialized='incremental',
        unique_key='transaction_id',
        incremental_strategy='delete+insert',
        on_schema_change='sync_all_columns'
    )
}}

/*
  Grain: one row per transaction.
  Enriches stg_transactions with account and customer context.
  Normalises amounts to UAH via exchange rates.
  Window functions:
    - running_balance_uah: cumulative balance per account over time
    - txn_recency_rank: most recent transaction per account = 1
*/

with transactions as (
    select * from {{ ref('stg_transactions') }}
),

accounts as (
    select
        account_id,
        customer_id,
        account_type,
        currency as account_currency
    from {{ ref('stg_accounts') }}
),

customers as (
    select
        customer_id,
        first_name || ' ' || last_name  as customer_name,
        customer_segment,
        city                            as customer_city,
        region                          as customer_region
    from {{ ref('stg_customers') }}
),

exchange_rates as (
    select
        currency_from,
        currency_to,
        rate,
        row_number() over (
            partition by currency_from, currency_to
            order by rate_date desc
        ) as rn
    from {{ ref('stg_exchange_rates') }}
),

latest_rates as (
    select currency_from, currency_to, rate
    from exchange_rates
    where rn = 1
),

enriched as (
    select
        t.transaction_id,
        t.account_id,
        a.customer_id,
        c.customer_name,
        c.customer_segment,
        c.customer_region,

        t.transaction_date,
        t.transaction_time,
        t.transaction_timestamp,
        t.transaction_type,
        t.merchant_category,
        t.merchant_name,
        t.city,
        t.country,
        t.channel,
        t.status,

        t.amount,
        t.currency,
        t.amount_abs,
        t.transaction_direction,
        t.is_flagged,
        t.is_weekend,
        t.is_high_value,

        -- normalise to UAH
        case
            when t.currency = 'UAH' then t.amount_abs
            else t.amount_abs * coalesce(r.rate, 1)
        end as amount_uah,

        -- running balance per account ordered by time
        sum(t.amount) over (
            partition by t.account_id
            order by t.transaction_timestamp
            rows between unbounded preceding and current row
        ) as running_balance_uah,

        -- most recent transaction per account = 1
        row_number() over (
            partition by t.account_id
            order by t.transaction_timestamp desc
        ) as txn_recency_rank

    from transactions t
    left join accounts     a on t.account_id  = a.account_id
    left join customers    c on a.customer_id = c.customer_id
    left join latest_rates r
           on t.currency   = r.currency_from
          and r.currency_to = 'UAH'
)

select * from enriched
where {{ incremental_date_filter('transaction_date') }}
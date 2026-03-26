with source as (
    select * from {{ ref('raw_fraud_alerts') }}
),

cleaned as (
    select
        alert_id,
        transaction_id,
        account_id,
        cast(alert_date as date)                             as alert_date,
        {{ standardize_text('alert_type') }}                 as alert_type,
        cast(risk_score as numeric(5,2))                     as risk_score,
        {{ standardize_text('investigation_status') }}       as investigation_status,


        cast(is_confirmed_fraud as boolean)                  as is_confirmed_fraud,
        {{ standardize_text('fraud_type') }}                 as fraud_type,

        cast(loss_amount as numeric(18,2))                   as loss_amount

    from source
)

select * from cleaned
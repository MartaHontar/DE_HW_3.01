
  
  create view "privatbank"."main"."stg_fraud_alerts__dbt_tmp" as (
    with source as (
    select * from "privatbank"."main"."raw_fraud_alerts"
),

cleaned as (
    select
        alert_id,
        transaction_id,
        account_id,
        cast(alert_date as date)                             as alert_date,
        
    initcap(trim(lower(alert_type)))
                 as alert_type,
        cast(risk_score as numeric(5,2))                     as risk_score,
        
    initcap(trim(lower(investigation_status)))
       as investigation_status,


        cast(is_confirmed_fraud as boolean)                  as is_confirmed_fraud,
        
    initcap(trim(lower(fraud_type)))
                 as fraud_type,

        cast(loss_amount as numeric(18,2))                   as loss_amount

    from source
)

select * from cleaned
  );

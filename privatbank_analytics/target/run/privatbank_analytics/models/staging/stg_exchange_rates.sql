
  
  create view "privatbank"."main"."stg_exchange_rates__dbt_tmp" as (
    with source as (
    select * from "privatbank"."main"."raw_exchange_rates"
),

cleaned as (
    select
        rate_id,
        cast(rate_date as date)                   as rate_date,
        upper(currency_from)                      as currency_from,
        upper(currency_to)                        as currency_to,
        cast(rate as numeric(18,6))               as rate
    from source
)

select * from cleaned
  );

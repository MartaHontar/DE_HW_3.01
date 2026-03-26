
  
  create view "privatbank"."main"."raw_exchange_rates__dbt_tmp" as (
    select * from "privatbank"."main"."exchange_rates"
  );

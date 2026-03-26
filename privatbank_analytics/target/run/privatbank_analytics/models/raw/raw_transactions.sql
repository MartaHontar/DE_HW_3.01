
  
  create view "privatbank"."main"."raw_transactions__dbt_tmp" as (
    select * from "privatbank"."main"."transactions"
  );

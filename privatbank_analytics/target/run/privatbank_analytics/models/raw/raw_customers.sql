
  
  create view "privatbank"."main"."raw_customers__dbt_tmp" as (
    select * from "privatbank"."main"."customers"
  );

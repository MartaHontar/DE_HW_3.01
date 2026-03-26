
  
  create view "privatbank"."main"."raw_accounts__dbt_tmp" as (
    select * from "privatbank"."main"."accounts"
  );

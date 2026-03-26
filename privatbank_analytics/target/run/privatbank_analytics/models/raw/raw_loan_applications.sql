
  
  create view "privatbank"."main"."raw_loan_applications__dbt_tmp" as (
    select * from "privatbank"."main"."loan_applications"
  );


  
  create view "privatbank"."main"."raw_loan_repayments__dbt_tmp" as (
    select * from "privatbank"."main"."loan_repayments"
  );

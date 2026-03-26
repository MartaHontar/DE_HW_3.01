
  
  create view "privatbank"."main"."raw_fraud_alerts__dbt_tmp" as (
    select * from "privatbank"."main"."fraud_alerts"
  );

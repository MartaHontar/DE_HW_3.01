
  
  create view "privatbank"."main"."stg_customers__dbt_tmp" as (
    with source as (
    select * from "privatbank"."main"."raw_customers"
),
 
cleaned as (
    select
        customer_id,
        
    initcap(trim(lower(first_name)))
             as first_name,
        
    initcap(trim(lower(last_name)))
              as last_name,
        cast(date_of_birth as date)                      as date_of_birth,
        
    initcap(trim(lower(gender)))
                 as gender,
        phone,
        lower(email)                                     as email,
        
    initcap(trim(lower(city)))
                   as city,
        
    initcap(trim(lower(region)))
                 as region,
        cast(registration_date as date)                  as registration_date,
        
    initcap(trim(lower(customer_segment)))
       as customer_segment,
        cast(credit_score as integer)                    as credit_score,
        cast(is_active as boolean)                       as is_active,
 
        date_diff('year', cast(date_of_birth as date), current_date) as age_years,
 

        date_diff('day', cast(registration_date as date), current_date) as days_since_registration
 
    from source
)
 
select * from cleaned
  );

 
with source as (
    select * from {{ ref('raw_customers') }}
),
 
cleaned as (
    select
        customer_id,
        {{ standardize_text('first_name') }}             as first_name,
        {{ standardize_text('last_name') }}              as last_name,
        cast(date_of_birth as date)                      as date_of_birth,
        {{ standardize_text('gender') }}                 as gender,
        phone,
        lower(email)                                     as email,
        {{ standardize_text('city') }}                   as city,
        {{ standardize_text('region') }}                 as region,
        cast(registration_date as date)                  as registration_date,
        {{ standardize_text('customer_segment') }}       as customer_segment,
        cast(credit_score as integer)                    as credit_score,
        cast(is_active as boolean)                       as is_active,
 
        date_diff('year', cast(date_of_birth as date), current_date) as age_years,
 

        date_diff('day', cast(registration_date as date), current_date) as days_since_registration
 
    from source
)
 
select * from cleaned
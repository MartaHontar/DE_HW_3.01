with source as (
    select * from {{ ref('raw_accounts') }}
),
 
cleaned as (
    select
        account_id,
        customer_id,
        {{ standardize_text('account_type') }}   as account_type,
        {{ standardize_text('currency') }}        as currency,
        cast(opened_date as date)                 as opened_date,
        {{ standardize_text('status') }}          as account_status,
        cast(credit_limit as decimal(18, 2))      as credit_limit,
        cast(current_balance as decimal(18, 2))   as current_balance,
        cast(overdraft_limit as decimal(18, 2))   as overdraft_limit,
 
        case
            when account_type = 'CURRENT'
            then cast(current_balance as decimal(18,2)) + cast(overdraft_limit as decimal(18,2))
            else cast(current_balance as decimal(18,2))
        end                                       as available_balance
 
    from source
)
 
select * from cleaned
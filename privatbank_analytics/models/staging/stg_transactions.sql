with source as (
    select * from {{ ref('raw_transactions') }}
),

cleaned as (
    select
        transaction_id,
        account_id,

        -- Dates & time
        cast(transaction_date as date)                       as transaction_date,
        cast(transaction_time as time)                       as transaction_time,

        -- Amount & currency
        cast(amount as numeric(18,2))                        as amount,
        upper(currency)                                      as currency,

        -- Transaction details
        {{ standardize_text('transaction_type') }}           as transaction_type,
        {{ standardize_text('merchant_category') }}          as merchant_category,
        {{ standardize_text('merchant_name') }}              as merchant_name,

        -- Location
        {{ standardize_text('city') }}                       as city,
        upper(country)                                       as country,

        -- Channel & status
        {{ standardize_text('channel') }}                    as channel,
        {{ standardize_text('status') }}                     as status,

        -- Flags
        cast(is_flagged as boolean)                          as is_flagged,

        -- ======================
        -- Derived fields
        -- ======================

        -- Combine date + time into timestamp
        cast(
            concat(transaction_date, ' ', transaction_time) 
            as timestamp
        )                                                    as transaction_timestamp,

        -- Absolute value for analysis
        abs(cast(amount as numeric(18,2)))                   as amount_abs,

        -- Transaction direction
        case
            when amount < 0 then 'debit'
            when amount > 0 then 'credit'
            else 'zero'
        end                                                  as transaction_direction,

        -- Weekend indicator
        case
            when extract(dow from cast(transaction_date as date)) in (0,6)
            then true else false
        end                                                  as is_weekend,

     
        case
            when abs(amount) > 1000 then true
            else false
        end                                                  as is_high_value

    from source
)

select * from cleaned
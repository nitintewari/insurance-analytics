-- stg_members.sql
-- Cleans member/policyholder data. Adds derived age bucket and enrollment year/month.

with source as (
    select * from {{ source('raw', 'members') }}
),

renamed as (
    select
        member_id,
        trim(first_name)                        as first_name,
        trim(last_name)                         as last_name,
        trim(first_name) || ' ' || trim(last_name)
                                                as full_name,
        lower(email)                            as email,
        phone,
        cast(dob as date)                       as dob,
        upper(state)                            as state,
        zip_code,
        cast(enrollment_date as date)           as enrollment_date,
        agent_id,
        carrier,
        plan_type,

        -- derived fields
        date_diff(current_date(), cast(dob as date), year)
                                                as age_years,
        case
            when date_diff(current_date(), cast(dob as date), year) < 30 then 'under_30'
            when date_diff(current_date(), cast(dob as date), year) < 45 then '30_to_44'
            when date_diff(current_date(), cast(dob as date), year) < 60 then '45_to_59'
            else '60_plus'
        end                                     as age_bucket,

        extract(year  from cast(enrollment_date as date))   as enrollment_year,
        extract(month from cast(enrollment_date as date))   as enrollment_month,

        -- plan category
        case
            when plan_type like '%Bundle%' then 'bundle'
            when plan_type like 'Dental%'  then 'dental'
            else 'vision'
        end                                     as plan_category

    from source
)

select * from renamed

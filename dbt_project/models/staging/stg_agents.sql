-- stg_agents.sql
-- Cleans and standardizes raw agent data from the source system.
-- One row per agent. Casts types, standardizes tier labels, flags inactive agents.

with source as (
    select * from {{ source('raw', 'agents') }}
),

renamed as (
    select
        agent_id,
        trim(agent_name)                        as agent_name,
        trim(agency_name)                       as agency_name,
        upper(state)                            as state,
        lower(email)                            as email,
        phone,
        cast(hire_date as date)                 as hire_date,
        cast(is_active as bool)                 as is_active,
        lower(tier)                             as tier,

        -- derived
        date_diff(current_date(), cast(hire_date as date), month)
                                                as months_tenure,
        case
            when lower(tier) = 'platinum' then 4
            when lower(tier) = 'gold'     then 3
            when lower(tier) = 'silver'   then 2
            else 1
        end                                     as tier_rank

    from source
)

select * from renamed

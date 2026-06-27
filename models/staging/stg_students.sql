WITH source AS (

    SELECT
        *
    FROM {{ ref('raw_students') }}

),

renamed AS (

    SELECT
        student_id,
        join_ts,
        country_code,
        acquisition_channel,
        persona,
        first_subject
    FROM source

)

SELECT
    *
FROM renamed
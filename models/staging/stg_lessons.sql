WITH source AS (
 
    SELECT
        *
    FROM {{ ref('raw_lessons') }}
 
),
 
renamed AS (
 
    SELECT
        lesson_id,
        student_id,
        booking_ts,
        hours_booked
    FROM source
 
)
 
SELECT
    *
FROM renamed
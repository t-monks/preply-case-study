WITH lessons AS (

    SELECT
        lesson_id,
        student_id,
        booking_ts,
        hours_booked
    FROM {{ ref('stg_lessons') }}

),

payment_cycles AS (

    SELECT
        student_id,
        payment_id,
        start_date,
        end_date,
        lifetime_payment_number
    FROM {{ ref('int_payment_cycle_dates') }}

),

mapped AS (

    SELECT
        lessons.lesson_id,
        lessons.student_id,
        lessons.booking_ts,
        lessons.hours_booked,
        payment_cycles.payment_id,
        payment_cycles.lifetime_payment_number,
        payment_cycles.start_date,
        payment_cycles.end_date
    FROM lessons
    LEFT JOIN payment_cycles
        ON lessons.student_id = payment_cycles.student_id
        AND lessons.booking_ts >= payment_cycles.start_date
        AND lessons.booking_ts < payment_cycles.end_date

)

SELECT
    lesson_id,
    student_id,
    booking_ts,
    hours_booked,
    payment_id,
    lifetime_payment_number,
    start_date,
    end_date
FROM mapped
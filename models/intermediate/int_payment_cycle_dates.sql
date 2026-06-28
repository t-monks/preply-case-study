WITH payments AS (

    SELECT
        payment_id,
        student_id,
        payment_ts, 
        hours, 
        price_per_hour_usd
    FROM {{ ref('stg_payments') }}

),

students AS (
    SELECT 
        student_id, 
        join_ts 
    FROM {{ ref('stg_students') }}
), 

cycles AS (

    SELECT
        student_id,
        payment_id,
        payment_ts AS start_date,
        DATEADD(DAY, 28, payment_ts) AS end_date,
        ROW_NUMBER() OVER (
            PARTITION BY student_id
            ORDER BY payment_ts
        ) AS lifetime_payment_number, 
        hours AS total_hours_purchased, 
        price_per_hour_usd
    FROM payments

)

SELECT
    cycles.student_id,
    cycles.payment_id,
    cycles.start_date,
    cycles.end_date,
    cycles.lifetime_payment_number, 
    students.join_ts, 
    cycles.total_hours_purchased, 
    cycles.price_per_hour_usd
FROM cycles 
LEFT JOIN students 
    ON students.student_id = cycles.student_id

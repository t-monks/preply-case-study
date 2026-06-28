WITH payments AS (

    SELECT
        payment_id,
        student_id,
        payment_ts, 
        hours, 
        price_per_hour_usd
    FROM {{ ref('stg_payments') }}

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
    student_id,
    payment_id,
    start_date,
    end_date,
    lifetime_payment_number, 
    total_hours_purchased, 
    price_per_hour_usd
FROM cycles

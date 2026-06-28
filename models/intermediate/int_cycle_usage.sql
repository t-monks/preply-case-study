WITH cycles AS (

    SELECT
        payment_id,
        student_id,
        lifetime_payment_number,
        start_date, 
        end_date, 
        total_hours_purchased, 
        price_per_hour_usd, 
        CASE WHEN 
            lifetime_payment_number >= 5
            THEN '5+'
            ELSE lifetime_payment_number::TEXT
        END AS lifetime_payment_number_bucket, 
        CASE WHEN price_per_hour_usd <= 10 
            THEN '0-10'
            WHEN price_per_hour_usd <= 15 
            THEN '10-15'
            WHEN price_per_hour_usd <= 20 
            THEN '15-20'
            ELSE '20+'
            END AS price_bucket
    FROM {{ ref('int_payment_cycle_dates') }}

),

usage AS (

    SELECT
        payment_id,
        SUM(hours_booked) AS total_hours_used
    FROM {{ ref('int_lesson_cycle_mapping') }}
    GROUP BY payment_id

),

joined AS (

    SELECT
        cycles.payment_id,
        cycles.student_id,
        cycles.start_date, 
        cycles.end_date, 
        cycles.lifetime_payment_number,
        cycles.lifetime_payment_number_bucket, 
        CASE
            WHEN cycles.end_date < CURRENT_TIMESTAMP THEN 1
            ELSE 0
        END AS is_cycle_ended,
        cycles.total_hours_purchased,
        COALESCE(usage.total_hours_used, 0) AS total_hours_used, 
        cycles.price_per_hour_usd, 
        cycles.price_bucket
    FROM cycles
    LEFT JOIN usage
        ON cycles.payment_id = usage.payment_id

)

SELECT
    payment_id,
    student_id,
    start_date, 
    end_date, 
    lifetime_payment_number,
    lifetime_payment_number_bucket, 
    is_cycle_ended,
    total_hours_purchased,
    total_hours_used,
    total_hours_used / NULLIF(total_hours_purchased, 0) AS pct_hours_used, 
    price_per_hour_usd,
    price_bucket
FROM joined

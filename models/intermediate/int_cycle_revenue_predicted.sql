WITH cycles AS (

    SELECT 
        payment_id, 
        student_id, 
        start_date, 
        end_date, 
        join_ts, 
        lifetime_payment_number_bucket, 
        lifetime_payment_number, 
        total_hours_purchased, 
        total_hours_used, 
        pct_hours_used, 
        price_per_hour_usd, 
        price_bucket
    FROM {{ ref('int_cycle_usage') }}

), 

student_dimensions AS (
    
    SELECT 
        student_id, 
        persona
    FROM {{ ref('stg_students') }}

), 

cohort_avg AS (

    SELECT 
        lifetime_payment_number_bucket, 
        price_bucket, 
        persona,
        avg_pct_hours_used
    FROM {{ ref('int_cohort_breakage_avg') }}

), 

predicted_pcts AS (

SELECT 
    cycles.payment_id, 
    cycles.student_id, 
    cycles.total_hours_purchased, 
    cycles.total_hours_used, 
    cycles.start_date, 
    cycles.end_date, 
    cycles.join_ts, 
    cycles.price_per_hour_usd, 
    cycles.lifetime_payment_number_bucket, 
    cycles.lifetime_payment_number, 
    cycles.price_bucket, 
    CASE WHEN 
        cycles.pct_hours_used >= avg.avg_pct_hours_used 
        THEN cycles.pct_hours_used 
        ELSE avg.avg_pct_hours_used 
        END AS predicted_pct_hours_used, 
    avg.avg_pct_hours_used AS cohort_pct_hours_used
FROM cycles 
LEFT JOIN student_dimensions student
    ON student.student_id = cycles.student_id 
LEFT JOIN cohort_avg avg 
    ON avg.lifetime_payment_number_bucket = cycles.lifetime_payment_number_bucket
    AND avg.price_bucket = cycles.price_bucket 
    AND avg.persona = student.persona 

)

SELECT 
    payment_id, 
    student_id, 
    start_date, 
    end_date, 
    join_ts, 
    total_hours_purchased, 
    lifetime_payment_number_bucket, 
    lifetime_payment_number, 
    price_bucket, 
    predicted_pct_hours_used * total_hours_purchased AS predicted_total_hours_used, 
    predicted_total_hours_used * price_per_hour_usd * 0.2 AS predicted_usage_revenue, 
    (total_hours_purchased - predicted_total_hours_used) * price_per_hour_usd AS predicted_breakage_revenue, 
    cohort_pct_hours_used

FROM predicted_pcts
    

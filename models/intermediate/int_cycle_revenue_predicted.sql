WITH cycles AS (

    SELECT 
        payment_id, 
        student_id, 
        start_date, 
        end_date, 
        lifetime_payment_number_bucket, 
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
    cycles.total_hours_purchased, 
    cycles.total_hours_used, 
    cycles.start_date, 
    cycles.end_date, 
    cycles.price_per_hour_usd, 
    CASE WHEN 
        cycles.pct_hours_used >= avg.avg_pct_hours_used 
        THEN cycles.pct_hours_used 
        ELSE avg.avg_pct_hours_used 
        END AS predicted_pct_hours_used
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
    start_date, 
    end_date, 
    total_hours_purchased, 
    predicted_pct_hours_used * total_hours_purchased AS predicted_total_hours_used, 
    predicted_total_hours_used * price_per_hour_usd * 0.2 AS predicted_usage_revenue, 
    (total_hours_purchased * price_per_hour_usd) - predicted_usage_revenue AS predicted_breakage_revenue

FROM predicted_pcts
    

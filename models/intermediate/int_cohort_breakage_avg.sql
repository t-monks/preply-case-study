WITH completed_cycles AS (

    SELECT 
        payment_id, 
        student_id, 
        lifetime_payment_number,  
        lifetime_payment_number_bucket, 
        breakage_revenue_usd,
        usage_revenue_usd, 
        pct_hours_used,
        price_bucket
    FROM {{ ref('int_cycle_revenue_completed') }}

), 

student_dimensions AS (

    SELECT 
        student_id, 
        persona
    FROM {{ ref('stg_students') }}

)

SELECT 
    cycles.lifetime_payment_number_bucket, 
    cycles.price_bucket, 
    students.persona,
    AVG(cycles.pct_hours_used) AS avg_pct_hours_used, 
    COUNT(*) AS total_cycles_in_cohort
FROM completed_cycles cycles 
LEFT JOIN student_dimensions students 
    ON students.student_id = cycles.student_id 
GROUP BY ALL 
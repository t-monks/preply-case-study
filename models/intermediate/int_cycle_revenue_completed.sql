WITH completed_cycles AS (

    SELECT 
        payment_id, 
        student_id, 
        lifetime_payment_number, 
        lifetime_payment_number_bucket, 
        total_hours_purchased, 
        total_hours_used, 
        pct_hours_used, 
        price_per_hour_usd, 
        price_bucket, 
        is_cycle_ended
    FROM {{ ref('int_cycle_usage') }}
    WHERE is_cycle_ended = 1

)
    
    SELECT 
        payment_id, 
        student_id, 
        lifetime_payment_number, 
        lifetime_payment_number_bucket, 
        price_per_hour_usd, 
        price_bucket,
        is_cycle_ended, 
        ROUND(
            (total_hours_used * price_per_hour_usd) * 0.2, 2) AS usage_revenue_usd, 
        ROUND(
            (total_hours_purchased - total_hours_used) * price_per_hour_usd, 2) AS breakage_revenue_usd, 
        pct_hours_used 
    FROM completed_cycles

WITH actual_revenue AS (
    
    SELECT 
        payment_id, 
        student_id, 
        lifetime_payment_number_bucket, 
        price_bucket,
        usage_revenue_usd, 
        breakage_revenue_usd, 
        usage_revenue_usd + breakage_revenue_usd AS total_revenue, 
        pct_hours_used, 
        is_cycle_ended
    FROM {{ ref('int_cycle_revenue_completed') }}
), 

predicted_revenue AS (

    SELECT 
        payment_id, 
        student_id, 
        start_date, 
        end_date, 
        lifetime_payment_number_bucket, 
        price_bucket, 
        predicted_usage_revenue, 
        predicted_breakage_revenue, 
        predicted_usage_revenue + predicted_breakage_revenue AS predicted_total_revenue
    FROM {{ ref('int_cycle_revenue_predicted') }}

), 

student_dimensions AS (

    SELECT 
        student_id, 
        persona, 
        country_code,
        acquisition_channel,
        first_subject
    FROM {{ ref('stg_students') }}

)

SELECT 
    predicted.payment_id, 
    predicted.start_date, 
    predicted.end_date, 
    predicted.predicted_usage_revenue, 
    predicted.predicted_breakage_revenue, 
    predicted.predicted_total_revenue, 
    actual.usage_revenue_usd, 
    actual.breakage_revenue_usd, 
    actual.total_revenue, 
    predicted.lifetime_payment_number_bucket, 
    predicted.price_bucket, 
    student.persona, 
    student.country_code, 
    student.acquisition_channel, 
    student.first_subject, 
    COALESCE(actual.is_cycle_ended, 0) AS is_cycle_ended
FROM predicted_revenue predicted 
LEFT JOIN actual_revenue actual 
    ON actual.payment_id = predicted.payment_id 
LEFT JOIN student_dimensions student 
    ON student.student_id = predicted.student_id 
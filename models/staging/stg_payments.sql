WITH source AS (

    SELECT
        *
    FROM {{ ref('raw_payments') }}

),

renamed AS (

    SELECT
        payment_id,
        student_id,
        payment_ts,
        hours,
        price_per_hour_usd
    FROM source

)

SELECT
    *
FROM renamed
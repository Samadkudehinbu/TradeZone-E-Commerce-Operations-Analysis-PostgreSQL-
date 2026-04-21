/*
	Question 1: Customer Acquisition and 30-Day Conversion
	Business Question: Find the top 5 states by number of new customer sign-ups in 2024. 
	For each state, calculate what percentage of these new customers made at least one 
	purchase within their first 30 days of signing up.
*/

WITH new_customers_2024 AS (
    -- All customers who signed up in 2024
    SELECT
        customer_id,
        state,
        signup_date
    FROM customers
    WHERE EXTRACT(YEAR FROM signup_date) = 2024
),
converted_customers AS (
    -- New customers who made at least one purchase
    -- within 30 days of signing up
    SELECT DISTINCT
        nc.customer_id,
        nc.state
    FROM new_customers_2024 nc
    JOIN orders o ON nc.customer_id = o.customer_id
    WHERE o.order_date >= nc.signup_date
      AND o.order_date <= nc.signup_date + INTERVAL '30 days'
      AND o.order_status != 'Cancelled'
),
state_signup_counts AS (
    -- Total new sign-ups per state in 2024
    SELECT
        state,
        COUNT(customer_id) AS total_signups
    FROM new_customers_2024
    GROUP BY state
),
state_conversion_counts AS (
    -- Total converted customers per state
    SELECT
        state,
        COUNT(customer_id) AS total_converted
    FROM converted_customers
    GROUP BY state
)
SELECT
    s.state,
    s.total_signups,
    COALESCE(c.total_converted, 0)              AS converted_within_30_days,
    ROUND(
        COALESCE(c.total_converted, 0) * 100.0
        / s.total_signups, 2
    )                                            AS conversion_rate_pct
FROM state_signup_counts s
LEFT JOIN state_conversion_counts c ON s.state = c.state
ORDER BY s.total_signups DESC
LIMIT 5;
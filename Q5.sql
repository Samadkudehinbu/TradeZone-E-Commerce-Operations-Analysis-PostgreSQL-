/*
	Question 5: Customer Spend Segmentation 
	Business Question: Segment customers based on their total
	spend in 2024 into three groups:
	High Spenders: ≥ ₦100,000
	Medium Spenders: ₦50,000 – ₦99,999
	Low Spenders: < ₦50,000
	For each group, calculate the customer count, average
	spend per customer and total revenue contribution.
*/
WITH customer_spend AS (
    -- Calculate total spend per customer in 2024
    SELECT
        o.customer_id,
        SUM(o.total_amount) AS total_spend
    FROM orders o
    WHERE EXTRACT(YEAR FROM o.order_date) = 2024
      AND o.order_status != 'Cancelled'
    GROUP BY o.customer_id
),
segmented AS (
    -- Assign spend segment to each customer
    SELECT
        customer_id,
        total_spend,
        CASE
            WHEN total_spend >= 100000 THEN 'High Spender'
            WHEN total_spend >= 50000  THEN 'Medium Spender'
            ELSE                            'Low Spender'
        END AS spend_segment
    FROM customer_spend
)
SELECT
    spend_segment,
    COUNT(customer_id)                        AS customer_count,
    ROUND(AVG(total_spend)::NUMERIC, 2)       AS avg_spend_per_customer,
    ROUND(SUM(total_spend)::NUMERIC, 2)       AS total_revenue_contribution
FROM segmented
GROUP BY spend_segment
ORDER BY
    CASE spend_segment
        WHEN 'High Spender'   THEN 1
        WHEN 'Medium Spender' THEN 2
        WHEN 'Low Spender'    THEN 3
    END;
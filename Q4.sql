/*
	Question 4: Quarterly Revenue Trends 
	Business Question: Compare quarterly revenue across 2023 and 2024. 
	For each quarter, calculate total revenue, average order value and total number of orders. 
	Identify which single quarter showed the strongest revenue growth
	from 2023 to 2024.
*/
WITH quarterly_revenue AS (
    -- Calculate revenue metrics per quarter per year
    SELECT
        EXTRACT(YEAR FROM order_date)     AS year,
        EXTRACT(QUARTER FROM order_date)  AS quarter,
        COUNT(order_id)                   AS total_orders,
        SUM(total_amount)                 AS total_revenue,
        ROUND(AVG(total_amount)::NUMERIC, 2) AS avg_order_value
    FROM orders
    WHERE order_status != 'Cancelled'
      AND EXTRACT(YEAR FROM order_date) IN (2023, 2024)
    GROUP BY
        EXTRACT(YEAR FROM order_date),
        EXTRACT(QUARTER FROM order_date)
),
pivoted AS (
    -- Pivot to compare 2023 vs 2024 side by side per quarter
    SELECT
        quarter,
        MAX(CASE WHEN year = 2023 THEN total_revenue END)    AS revenue_2023,
        MAX(CASE WHEN year = 2024 THEN total_revenue END)    AS revenue_2024,
        MAX(CASE WHEN year = 2023 THEN avg_order_value END)  AS avg_order_value_2023,
        MAX(CASE WHEN year = 2024 THEN avg_order_value END)  AS avg_order_value_2024,
        MAX(CASE WHEN year = 2023 THEN total_orders END)     AS total_orders_2023,
        MAX(CASE WHEN year = 2024 THEN total_orders END)     AS total_orders_2024
    FROM quarterly_revenue
    GROUP BY quarter
)
SELECT
    quarter,
    total_orders_2023,
    total_orders_2024,
    ROUND(revenue_2023::NUMERIC, 2)          AS revenue_2023,
    ROUND(revenue_2024::NUMERIC, 2)          AS revenue_2024,
    avg_order_value_2023,
    avg_order_value_2024,
    ROUND((revenue_2024 - revenue_2023)::NUMERIC, 2) AS revenue_growth,
    ROUND(
        (revenue_2024 - revenue_2023) * 100.0
        / NULLIF(revenue_2023, 0), 2
    )                                        AS growth_pct
FROM pivoted
ORDER BY growth_pct DESC;
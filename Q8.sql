/*
    Question 8: Top Seller Bonus Qualification
    Business Question: Identify the top 10 sellers in 2024
    by total revenue who completed at least 10 orders and
    have an average customer rating of 4.0 or above.
    Include their total orders, average rating, and total
    revenue.
*/

WITH seller_revenue AS (
    -- Calculate total revenue and completed order count
    -- per seller in 2024
    SELECT
        o.seller_id,
        COUNT(o.order_id)                       AS total_orders,
        ROUND(SUM(o.total_amount)::NUMERIC, 2)  AS total_revenue
    FROM orders o
    WHERE EXTRACT(YEAR FROM o.order_date) = 2024
      AND o.order_status = 'Delivered'
    GROUP BY o.seller_id
    HAVING COUNT(o.order_id) >= 10
),
seller_ratings AS (
    -- Calculate average customer rating per seller
    -- via products since reviews link to products not sellers
    SELECT
        p.seller_id,
        ROUND(AVG(r.rating)::NUMERIC, 2) AS avg_rating
    FROM reviews r
    JOIN products p ON r.product_id = p.product_id
    GROUP BY p.seller_id
)
SELECT
    sr.seller_id,
    s.seller_name,
    sr.total_orders,
    COALESCE(rt.avg_rating, 0)  AS avg_rating,
    sr.total_revenue
FROM seller_revenue sr
JOIN sellers s ON sr.seller_id = s.seller_id
LEFT JOIN seller_ratings rt ON sr.seller_id = rt.seller_id
WHERE COALESCE(rt.avg_rating, 0) >= 4.0
ORDER BY sr.total_revenue DESC
LIMIT 10;
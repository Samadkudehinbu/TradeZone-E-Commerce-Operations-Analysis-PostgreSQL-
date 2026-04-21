/*
	Question 2: Product Performance 
	Business Question: Identify the top 10 products by totalrevenue in 2024. 
	Include product name, category, total revenue and total number of orders. 
	Sort by revenue descending.
*/
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(oi.line_total)          AS total_revenue,
    COUNT(DISTINCT o.order_id)  AS total_orders
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2024
  AND o.order_status != 'Cancelled'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 10;
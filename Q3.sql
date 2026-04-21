/*
	Question 3: Seller Fulfilment Efficiency 
	Business Question: Calculate the average time in hours between order placement 
	and delivery for each seller. Return the top 20 sellers with the fastest average
	fulfilment times among sellers who have completed at least 20 orders. 
	Include their total completed orders and average customer rating.
*/

WITH completed_orders AS (
    -- Filter to delivered/completed orders only
    -- and calculate fulfilment time in hours per order
    SELECT
        o.seller_id,
        o.order_id,
        EXTRACT(EPOCH FROM (
            o.delivery_date::TIMESTAMP - o.order_date::TIMESTAMP
        )) / 3600 AS fulfilment_hours
    FROM orders o
    WHERE o.order_status = 'Delivered'
      AND o.delivery_date IS NOT NULL
      AND o.order_date IS NOT NULL
      AND o.delivery_date >= o.order_date
),
seller_fulfilment AS (
    -- Aggregate fulfilment stats per seller
    SELECT
        seller_id,
        COUNT(order_id)                     AS total_completed_orders,
        ROUND(AVG(fulfilment_hours)::NUMERIC, 2) AS avg_fulfilment_hours
    FROM completed_orders
    GROUP BY seller_id
    HAVING COUNT(order_id) >= 20
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
    sf.seller_id,
    s.seller_name,
    sf.total_completed_orders,
    sf.avg_fulfilment_hours,
    COALESCE(sr.avg_rating, 0) AS avg_customer_rating
FROM seller_fulfilment sf
JOIN sellers s ON sf.seller_id = s.seller_id
LEFT JOIN seller_ratings sr ON sf.seller_id = sr.seller_id
ORDER BY sf.avg_fulfilment_hours ASC
LIMIT 20;
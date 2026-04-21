/*
	Question 7: Review Ratings and Sales Performance
	Business Question: Group products based on their average
	review rating into three categories:
	High Rated: 4.0 and above
	Mid Rated: 3.0 – 3.99
	Low Rated: Below 3.0
	For each category, calculate the product count, total
	revenue and average unit price.
*/
WITH product_ratings AS (
    -- Calculate average rating per product
    SELECT
        product_id,
        ROUND(AVG(rating)::NUMERIC, 2) AS avg_rating
    FROM reviews
    GROUP BY product_id
),
product_revenue AS (
    -- Calculate total revenue per product in 2024
    SELECT
        oi.product_id,
        SUM(oi.line_total) AS total_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE EXTRACT(YEAR FROM o.order_date) = 2024
      AND o.order_status != 'Cancelled'
    GROUP BY oi.product_id
),
product_segments AS (
    -- Join ratings and revenue, assign rating category
    SELECT
        p.product_id,
        p.unit_price,
        COALESCE(pr.avg_rating, 0)      AS avg_rating,
        COALESCE(pv.total_revenue, 0)   AS total_revenue,
        CASE
            WHEN COALESCE(pr.avg_rating, 0) >= 4.0 THEN 'High Rated'
            WHEN COALESCE(pr.avg_rating, 0) >= 3.0 THEN 'Mid Rated'
            ELSE                                        'Low Rated'
        END AS rating_category
    FROM products p
    LEFT JOIN product_ratings pr ON p.product_id = pr.product_id
    LEFT JOIN product_revenue pv ON p.product_id = pv.product_id
)
SELECT
    rating_category,
    COUNT(product_id)                         AS product_count,
    ROUND(SUM(total_revenue)::NUMERIC, 2)     AS total_revenue,
    ROUND(AVG(unit_price)::NUMERIC, 2)        AS avg_unit_price
FROM product_segments
GROUP BY rating_category
ORDER BY
    CASE rating_category
        WHEN 'High Rated' THEN 1
        WHEN 'Mid Rated'  THEN 2
        WHEN 'Low Rated'  THEN 3
    END;
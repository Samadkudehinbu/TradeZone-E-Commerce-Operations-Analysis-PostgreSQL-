/*
	Question 6: Payment Method Preferences by State 
	Business Question: Analyse payment method preferences
	across each state in the dataset. For each state, show
	the transaction count and total amount for each payment
	method (Cash on Delivery, Card, Mobile Money, BankTransfer) 
	and identify the most popular method per state.
*/
WITH payment_by_state AS (
    -- Join payments to orders to get state via customers
    SELECT
        c.state,
        p.payment_method,
        COUNT(p.payment_id)            AS transaction_count,
        ROUND(SUM(p.amount)::NUMERIC, 2) AS total_amount
    FROM payments p
    JOIN orders o ON p.order_id = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE p.payment_method IS NOT NULL
      AND c.state IS NOT NULL
    GROUP BY c.state, p.payment_method
),
ranked AS (
    -- Rank payment methods per state by transaction count
    SELECT
        state,
        payment_method,
        transaction_count,
        total_amount,
        RANK() OVER (
            PARTITION BY state
            ORDER BY transaction_count DESC
        ) AS rank
    FROM payment_by_state
)
SELECT
    state,
    payment_method,
    transaction_count,
    total_amount,
    CASE WHEN rank = 1 THEN 'Most Popular' ELSE '' END AS popularity
FROM ranked
ORDER BY state, transaction_count DESC;
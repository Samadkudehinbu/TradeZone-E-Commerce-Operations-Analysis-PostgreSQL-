-- TRADEZONE E-COMMERCE PLATFORM - SQL ANAYLSIS USING PostgreSQL

-- PART A: DATA CLEANING & PREPARATION

-- SECTION 1. MISSING VALUES
-- Identify and handle NULLs/blanks in critical columns

-- 1a. CUSTOMERS

-- Flag: NULL emails — customer is still trackable via orders
-- No deletion; excluded naturally in email-specific queries
SELECT customer_id, first_name, last_name
FROM customers
WHERE email IS NULL OR TRIM(email) = '';
-- There are 15 customers with NULL emais

-- Flag: NULL city or state — excluded from geo queries only
SELECT customer_id, first_name, last_name
FROM customers
WHERE city IS NULL OR state IS NULL;
-- There are no customers with NULL city or state

-- Flag: NULL signup_date — excluded from acquisition queries
SELECT customer_id
FROM customers
WHERE signup_date IS NULL;
-- There are no customers with NULL signup_date

-- Flag: NULL account_status — treated as unknown in filters
SELECT customer_id
FROM customers
WHERE account_status IS NULL OR TRIM(account_status) = '';
-- There are no customers with NULL account_status


-- 1b. SELLERS

-- Flag: NULL city or state — excluded from geo queries only
SELECT seller_id, seller_name
FROM sellers
WHERE city IS NULL OR state IS NULL;
-- There are no sellers with NULL city or state

-- Flag: NULL onboarding_date — excluded from tenure queries
SELECT seller_id, seller_name
FROM sellers
WHERE onboarding_date IS NULL;
-- There are no sellers with NULL onboarding _date

-- Flag: NULL account_status
SELECT seller_id, seller_name
FROM sellers
WHERE account_status IS NULL OR TRIM(account_status) = '';
-- There are no sellers with NULL account_status


-- 1c. PRODUCTS

-- Delete: NULL seller_id — product is orphaned, cannot be
-- attributed to any seller; breaks all seller-product joins.
-- Must clear dependent tables first due to FK constraints.
DELETE FROM reviews
WHERE product_id IN (
    SELECT product_id FROM products WHERE seller_id IS NULL
);

DELETE FROM order_items
WHERE product_id IN (
    SELECT product_id FROM products WHERE seller_id IS NULL
);

DELETE FROM products
WHERE seller_id IS NULL;
-- Decision: Orphaned products have no operational owner.
-- Retaining them would silently corrupt revenue attribution.


-- Delete: NULL unit_price — product cannot contribute to
-- any revenue or validation calculation.
-- Must clear dependent tables first due to FK constraints.
DELETE FROM reviews
WHERE product_id IN (
    SELECT product_id FROM products WHERE unit_price IS NULL
);

DELETE FROM order_items
WHERE product_id IN (
    SELECT product_id FROM products WHERE unit_price IS NULL
);

DELETE FROM products
WHERE unit_price IS NULL;
-- Decision: A product with no price is analytically inert
-- and would cause NULL propagation in order_items joins.

-- Flag: NULL category — product retained but excluded from category-level analysis 
SELECT product_id, product_name
FROM products
WHERE category IS NULL OR TRIM(category) = '';
-- There were no products with NULL cagetories


-- 1d. ORDERS
-- Delete: NULL customer_id — order cannot be attributed.
-- Clear dependent tables first due to FK constraints.
DELETE FROM reviews
WHERE order_id IN (
    SELECT order_id FROM orders WHERE customer_id IS NULL
);

DELETE FROM payments
WHERE order_id IN (
    SELECT order_id FROM orders WHERE customer_id IS NULL
);

DELETE FROM order_items
WHERE order_id IN (
    SELECT order_id FROM orders WHERE customer_id IS NULL
);

DELETE FROM orders
WHERE customer_id IS NULL;
-- Decision: Customer attribution is required for retention,
-- segmentation and acquisition analysis (Q1, Q5).


-- Delete: NULL seller_id — order cannot be attributed.
DELETE FROM reviews
WHERE order_id IN (
    SELECT order_id FROM orders WHERE seller_id IS NULL
);

DELETE FROM payments
WHERE order_id IN (
    SELECT order_id FROM orders WHERE seller_id IS NULL
);

DELETE FROM order_items
WHERE order_id IN (
    SELECT order_id FROM orders WHERE seller_id IS NULL
);

DELETE FROM orders
WHERE seller_id IS NULL;
-- Decision: Seller attribution is required for fulfilment
-- and bonus qualification analysis (Q3, Q8).


-- Delete: NULL order_date — cannot be placed in any time window.
DELETE FROM reviews
WHERE order_id IN (
    SELECT order_id FROM orders WHERE order_date IS NULL
);

DELETE FROM payments
WHERE order_id IN (
    SELECT order_id FROM orders WHERE order_date IS NULL
);

DELETE FROM order_items
WHERE order_id IN (
    SELECT order_id FROM orders WHERE order_date IS NULL
);

DELETE FROM orders
WHERE order_date IS NULL;
-- Decision: Every time-based query (Q1–Q8) depends on
-- order_date. A dateless order is unanalysable.


-- Delete: NULL total_amount — revenue figure is missing.
DELETE FROM reviews
WHERE order_id IN (
    SELECT order_id FROM orders WHERE total_amount IS NULL
);

DELETE FROM payments
WHERE order_id IN (
    SELECT order_id FROM orders WHERE total_amount IS NULL
);

DELETE FROM order_items
WHERE order_id IN (
    SELECT order_id FROM orders WHERE total_amount IS NULL
);

DELETE FROM orders
WHERE total_amount IS NULL;
-- Decision: total_amount is the primary revenue field.
-- NULL here breaks Q4, Q5, Q6 and Q8 directly.


-- 1e. ORDER_ITEMS

-- Delete: NULL order_id — line item cannot be linked to any order
DELETE FROM order_items
WHERE order_id IS NULL;

-- Delete: NULL quantity, unit_price or line_total —
-- record is unusable for validation or revenue calculation
DELETE FROM order_items
WHERE quantity IS NULL
   OR unit_price IS NULL
   OR line_total IS NULL;
-- Decision: All three fields are required for the total_amount validation check 


-- 1f. PAYMENTS

-- Delete: NULL order_id — payment cannot be linked to an order
DELETE FROM payments
WHERE order_id IS NULL;
-- Decision: Unlinked payments cannot contribute to (payment method analysis) or any revenue reconciliation.

-- Delete: NULL amount — payment has no value
DELETE FROM payments
WHERE amount IS NULL;
-- Decision: A payment record with no amount is meaningless for any financial analysis.

-- Flag: NULL payment_method — record retained but excluded from payment preference analysis
SELECT payment_id, order_id
FROM payments
WHERE payment_method IS NULL OR TRIM(payment_method) = '';
-- There were no payments with NULL order_id


-- 1g. REVIEWS

-- Flag: NULL review_date — rating is still valid for seller and product performance scoring 
SELECT review_id, product_id, customer_id
FROM reviews
WHERE review_date IS NULL;
-- There were no reviews NULL review_dates

-- Delete: NULL rating — the core value of the record is missing
DELETE FROM reviews
WHERE rating IS NULL;
-- Decision: A review without a rating contributes nothing to average rating calculations




-- SECTION 2: DUPLICATE RECORDS
-- Check for and remove duplicate rows in customers, sellers and orders. 

-- 2a. CUSTOMERS 
-- Identify duplicate customers by email
-- Same email = same person registered more than once
SELECT email, COUNT(*) AS occurrences
FROM customers
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;

-- Before deleting duplicate customers, reassign or delete
-- their dependent orders, reviews to avoid FK violations.
-- We delete dependents of the duplicate (non-kept) customer_ids.

-- Delete reviews linked to duplicate customer records
DELETE FROM reviews
WHERE customer_id IN (
    SELECT customer_id FROM customers
    WHERE email IS NOT NULL
      AND customer_id NOT IN (
          SELECT MIN(customer_id)
          FROM customers
          WHERE email IS NOT NULL
          GROUP BY email
      )
);

-- Delete orders linked to duplicate customer records
-- (cascades to order_items and payments handled below)
DELETE FROM order_items
WHERE order_id IN (
    SELECT order_id FROM orders
    WHERE customer_id IN (
        SELECT customer_id FROM customers
        WHERE email IS NOT NULL
          AND customer_id NOT IN (
              SELECT MIN(customer_id)
              FROM customers
              WHERE email IS NOT NULL
              GROUP BY email
          )
    )
);

DELETE FROM payments
WHERE order_id IN (
    SELECT order_id FROM orders
    WHERE customer_id IN (
        SELECT customer_id FROM customers
        WHERE email IS NOT NULL
          AND customer_id NOT IN (
              SELECT MIN(customer_id)
              FROM customers
              WHERE email IS NOT NULL
              GROUP BY email
          )
    )
);

DELETE FROM orders
WHERE customer_id IN (
    SELECT customer_id FROM customers
    WHERE email IS NOT NULL
      AND customer_id NOT IN (
          SELECT MIN(customer_id)
          FROM customers
          WHERE email IS NOT NULL
          GROUP BY email
      )
);

-- Now safe to delete duplicate customer records
DELETE FROM customers
WHERE email IS NOT NULL
  AND customer_id NOT IN (
      SELECT MIN(customer_id)
      FROM customers
      WHERE email IS NOT NULL
      GROUP BY email
  );
-- Decision: Duplicate emails indicate the same person
-- registered twice. Keeping the earliest record preserves
-- the original signup date for acquisition analysis


-- 2b. SELLERS

-- Identify duplicate sellers by name + city + state
SELECT seller_name, city, state, COUNT(*) AS occurrences
FROM sellers
GROUP BY seller_name, city, state
HAVING COUNT(*) > 1;
-- There are no duplicate sellers in the sellers table

-- 2c. ORDERS

-- Identify duplicate orders
-- Same customer + seller + date + amount = accidental double-entry
SELECT customer_id, seller_id, order_date, total_amount,
       COUNT(*) AS occurrences
FROM orders
GROUP BY customer_id, seller_id, order_date, total_amount
HAVING COUNT(*) > 1;
-- There are no duplicate orders in the orders table




-- SECTION 3: INCONSISTENT FORMATTING
-- Standardise city names. Ensure all date columns follow a consistent format (YYYY-MM-DD). 
-- Normalise product category names to title case.


-- 3a. CITY NAME STANDARDISATION

-- Inspect distinct city values before cleaning
SELECT DISTINCT city FROM customers ORDER BY city;
SELECT DISTINCT city FROM sellers ORDER BY city;

-- Step 1: Fix malformed Port Harcourt variants first
-- Strips all spaces and hyphens before comparing to catch
-- "Port-Harcourt", "PortHarcourt", "Portharcourt" in one go
UPDATE customers
SET city = 'Port Harcourt'
WHERE TRIM(REGEXP_REPLACE(city, '[\s\-]+', '', 'g')) ILIKE 'portharcourt';

UPDATE sellers
SET city = 'Port Harcourt'
WHERE TRIM(REGEXP_REPLACE(city, '[\s\-]+', '', 'g')) ILIKE 'portharcourt';

-- Step 2: Fix malformed Lagos variants
-- Strips all internal spaces before comparing to catch
-- "Lago s", "Lago S" and any similar mid-word typos
UPDATE customers
SET city = 'Lagos'
WHERE TRIM(REGEXP_REPLACE(city, '\s+', '', 'g')) ILIKE 'lagos'
  AND city <> 'Lagos';

UPDATE sellers
SET city = 'Lagos'
WHERE TRIM(REGEXP_REPLACE(city, '\s+', '', 'g')) ILIKE 'lagos'
  AND city <> 'Lagos';

-- Step 3: Apply general standardisation to all remaining values
-- Handles case issues and whitespace across all tables and columns
UPDATE customers
SET city  = INITCAP(TRIM(REGEXP_REPLACE(city, '\s+', ' ', 'g'))),
    state = INITCAP(TRIM(REGEXP_REPLACE(state, '\s+', ' ', 'g')))
WHERE city IS NOT NULL OR state IS NOT NULL;

UPDATE sellers
SET city  = INITCAP(TRIM(REGEXP_REPLACE(city, '\s+', ' ', 'g'))),
    state = INITCAP(TRIM(REGEXP_REPLACE(state, '\s+', ' ', 'g')))
WHERE city IS NOT NULL OR state IS NOT NULL;

-- Verify — expected values only:
-- Abuja, Ibadan, Kano, Lagos, Port Harcourt
SELECT DISTINCT city FROM customers ORDER BY city;
SELECT DISTINCT city FROM sellers ORDER BY city;


-- 3b. DATE FORMAT VERIFICATION

-- DATE columns (signup_date, onboarding_date, order_date,
-- delivery_date, review_date) are stored as PostgreSQL DATE
-- type which enforces YYYY-MM-DD internally.
-- TIMESTAMP column (payment_date) stores full precision.
-- We verify consistency rather than reformat.

-- Verify customers.signup_date
SELECT customer_id, signup_date
FROM customers
WHERE signup_date IS NOT NULL
  AND signup_date::TEXT NOT LIKE '____-__-__';

-- Verify sellers.onboarding_date
SELECT seller_id, onboarding_date
FROM sellers
WHERE onboarding_date IS NOT NULL
  AND onboarding_date::TEXT NOT LIKE '____-__-__';

-- Verify orders.order_date and delivery_date
SELECT order_id, order_date, delivery_date
FROM orders
WHERE (order_date IS NOT NULL 
       AND order_date::TEXT NOT LIKE '____-__-__')
   OR (delivery_date IS NOT NULL 
       AND delivery_date::TEXT NOT LIKE '____-__-__');

-- Verify payments.payment_date (TIMESTAMP — check date portion)
SELECT payment_id, payment_date
FROM payments
WHERE payment_date IS NOT NULL
  AND payment_date::DATE::TEXT NOT LIKE '____-__-__';

-- Verify reviews.review_date
SELECT review_id, review_date
FROM reviews
WHERE review_date IS NOT NULL
  AND review_date::TEXT NOT LIKE '____-__-__';

-- Decision: All date columns are native PostgreSQL DATE or
-- TIMESTAMP types. Format is enforced at the type level.


-- 3c. PRODUCT CATEGORY - TITLE CASE

-- Inspect distinct category values before standardising
SELECT DISTINCT category FROM products ORDER BY category;
SELECT DISTINCT product_category FROM sellers ORDER BY product_category;

-- Step 1: Fix typos explicitly before any general standardisation
UPDATE products SET category = 'Electronics' WHERE TRIM(category) ILIKE 'Electronis';
UPDATE products SET category = 'Fashion' WHERE TRIM(category) ILIKE 'Fashon';

UPDATE sellers SET product_category = 'Electronics' WHERE TRIM(product_category) ILIKE 'Electronis';
UPDATE sellers SET product_category = 'Fashion' WHERE TRIM(product_category) ILIKE 'Fashon';

-- Step 2: Normalise "and" to "&" across all compound categories
UPDATE products
SET category = REGEXP_REPLACE(category, '\sand\s', ' & ', 'gi')
WHERE category ILIKE '%and%';

UPDATE sellers
SET product_category = REGEXP_REPLACE(product_category, '\sand\s', ' & ', 'gi')
WHERE product_category ILIKE '%and%';

-- Step 3: Map short/abbreviated forms to full canonical names
-- "BEAUTY" → "Beauty & Personal Care"
UPDATE products SET category = 'Beauty & Personal Care'
WHERE TRIM(UPPER(category)) = 'BEAUTY';

UPDATE sellers SET product_category = 'Beauty & Personal Care'
WHERE TRIM(UPPER(product_category)) = 'BEAUTY';

-- "BOOKS" → "Books & Stationery"
UPDATE products SET category = 'Books & Stationery'
WHERE TRIM(UPPER(category)) = 'BOOKS';

UPDATE sellers SET product_category = 'Books & Stationery'
WHERE TRIM(UPPER(product_category)) = 'BOOKS';

-- "FOOD" → "Food & Beverages"
UPDATE products SET category = 'Food & Beverages'
WHERE TRIM(UPPER(category)) = 'FOOD';

UPDATE sellers SET product_category = 'Food & Beverages'
WHERE TRIM(UPPER(product_category)) = 'FOOD';

-- "SPORTS" → "Sports & Fitness"
UPDATE products SET category = 'Sports & Fitness'
WHERE TRIM(UPPER(category)) = 'SPORTS';

UPDATE sellers SET product_category = 'Sports & Fitness'
WHERE TRIM(UPPER(product_category)) = 'SPORTS';

-- Step 4: Apply general INITCAP + TRIM standardisation
-- to handle remaining case inconsistencies
UPDATE products
SET category = INITCAP(TRIM(REGEXP_REPLACE(category, '\s+', ' ', 'g')))
WHERE category IS NOT NULL;

UPDATE sellers
SET product_category = INITCAP(TRIM(REGEXP_REPLACE(product_category, '\s+', ' ', 'g')))
WHERE product_category IS NOT NULL;

-- Verify Clean values:
SELECT DISTINCT category FROM products ORDER BY category;
SELECT DISTINCT product_category FROM sellers ORDER BY product_category;





-- SECTION 4: DATA VALIDATION
-- Verify that each order's total_amount matches the sum of its line items in order_items. 
-- Flag orders where the difference is greater than ₦10. 
-- Check that all review ratings are between 1 and 5. 
--Check for negative product prices or discount percentages above 100%.


-- 4a. ORDER TOTAL VERIFICATION
-- Verify that each order's total_amount matches the sum of its line items in order_items.
-- Flag orders where the difference is greater than ₦10.

-- First inspect the discrepancies
SELECT
    o.order_id,
    o.total_amount                            AS recorded_total,
    SUM(oi.line_total)                        AS calculated_total,
    ABS(o.total_amount - SUM(oi.line_total))  AS difference
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING ABS(o.total_amount - SUM(oi.line_total)) > 10
ORDER BY difference DESC;

-- Create a flag table to document discrepant orders
-- Decision: We do not delete or alter these orders as the
-- discrepancy may be due to applied discounts or fees not
-- captured in order_items. Flagging preserves the records
-- while making the issue visible for business review.
CREATE TABLE IF NOT EXISTS flagged_order_totals AS
SELECT
    o.order_id,
    o.customer_id,
    o.seller_id,
    o.order_date,
    o.total_amount                            AS recorded_total,
    SUM(oi.line_total)                        AS calculated_total,
    ABS(o.total_amount - SUM(oi.line_total))  AS difference
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY
    o.order_id,
    o.customer_id,
    o.seller_id,
    o.order_date,
    o.total_amount
HAVING ABS(o.total_amount - SUM(oi.line_total)) > 10
ORDER BY difference DESC;

-- Confirm how many orders were flagged
SELECT COUNT(*) AS flagged_order_count FROM flagged_order_totals;


-- 4b. LINE ITEM CALCULATION CHECK
-- Verify that order_items.line_total matches quantity x unit_price
-- Flag rows where they do not match (threshold: ₦0.01)
SELECT
    item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    line_total                                AS recorded_line_total,
    (quantity * unit_price)                   AS calculated_line_total,
    ABS(line_total - (quantity * unit_price)) AS difference
FROM order_items
WHERE ABS(line_total - (quantity * unit_price)) > 0.01
ORDER BY difference DESC;

-- Query returned 0 rows — all line_total values correctly
-- match quantity x unit_price within the ₦0.01 threshold.
-- No flagging or deletion required.


-- 4c. REVIEW RATING RANGE VALIDATION

-- Check that all review ratings are between 1 and 5
SELECT
    review_id,
    product_id,
    customer_id,
    rating
FROM reviews
WHERE rating < 1 OR rating > 5;

-- Delete invalid ratings — a rating outside 1–5 is not a
-- valid data entry and cannot be used in any scoring logic
DELETE FROM reviews
WHERE rating < 1 OR rating > 5;
-- Decision: Ratings outside the 1–5 scale are data entry
-- errors. They would skew average rating calculations in future analysis


--4d. NEGATIVE PRODUCT PRICES

-- ── 4d. NEGATIVE PRODUCT PRICES ───────────────────────────

-- Check for negative unit prices in products table
SELECT
    product_id,
    product_name,
    category,
    unit_price
FROM products
WHERE unit_price < 0;

-- Query returned 0 rows — no negative unit prices found
-- in the products table.
-- No deletion required.



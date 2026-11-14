
-- Customer Retention & Cohort Analysis
-- Check cleaned orders and customers tables

-- Query 1: Check the first 5 orders
SELECT TOP 5 *
FROM dbo.orders_cleaned;

-- Query 2: Check the first 5 customers
SELECT TOP 5 *
FROM dbo.customers_cleaned;


-- Query 3: Identify repeat customers
-- Only delivered orders are included

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM dbo.orders_cleaned AS o
INNER JOIN dbo.customers_cleaned AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER BY total_orders DESC;


-- Query 4: Calculate Repeat Purchase Rate
-- Only delivered orders are included

WITH CustomerOrders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM dbo.orders_cleaned AS o
    INNER JOIN dbo.customers_cleaned AS c
    ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    CAST(100.0 * SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) AS DECIMAL(10, 2)) AS repeat_purchase_rate
FROM CustomerOrders;


-- Query 5: Identify Each Customer's First Purchase Month(customer's acquisition cohort)
-- Cohort = month of first delivered purchase

SELECT
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp) AS first_purchase_date,
    CONVERT(CHAR(7), MIN(o.order_purchase_timestamp), 120) AS cohort_month
FROM dbo.orders_cleaned AS o
INNER JOIN dbo.customers_cleaned AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND o.order_purchase_timestamp IS NOT NULL
GROUP BY c.customer_unique_id
ORDER BY first_purchase_date;



-- Query 6: Count new customers in each acquisition month
-- Only delivered orders are included

WITH FirstPurchase AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM dbo.orders_cleaned AS o
    INNER JOIN dbo.customers_cleaned AS c
    ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp IS NOT NULL
    GROUP BY c.customer_unique_id
)
SELECT
    CONVERT(CHAR(7), first_purchase_date, 120) AS cohort_month,
    COUNT(*) AS new_customers
FROM FirstPurchase
GROUP BY CONVERT(CHAR(7), first_purchase_date, 120)
ORDER BY cohort_month;



-- Query 7: Calculate monthly customer retention
-- Month 0 = first purchase month
-- Month 1 = following calendar month
-- Month 2 = two calendar months later

WITH CustomerPurchases AS (
    SELECT DISTINCT
        c.customer_unique_id,
        o.order_id,
        DATEFROMPARTS(YEAR(o.order_purchase_timestamp),MONTH(o.order_purchase_timestamp),1) AS purchase_month
    FROM dbo.orders_cleaned AS o
    INNER JOIN dbo.customers_cleaned AS c
    ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp IS NOT NULL
),
CustomerCohorts AS (
    SELECT
        customer_unique_id,
        MIN(purchase_month) AS cohort_month
    FROM CustomerPurchases
    GROUP BY customer_unique_id
),
CohortActivity AS (
    SELECT DISTINCT
        p.customer_unique_id,
        c.cohort_month,
        DATEDIFF(MONTH,c.cohort_month,p.purchase_month) AS month_number
    FROM CustomerPurchases AS p
    INNER JOIN CustomerCohorts AS c
    ON p.customer_unique_id = c.customer_unique_id
)
SELECT
    CONVERT(CHAR(7), cohort_month, 120) AS cohort_month,
    month_number,
    COUNT(DISTINCT customer_unique_id) AS active_customers
FROM CohortActivity
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;



-- Query 8: Calculate Month 1 and Month 2 retention rates
-- Only delivered orders are included
-- Month 0 = customer's first purchase month

WITH CustomerPurchases AS (
    SELECT DISTINCT
        c.customer_unique_id,
        DATEFROMPARTS(YEAR(o.order_purchase_timestamp),MONTH(o.order_purchase_timestamp),1) AS purchase_month
    FROM dbo.orders_cleaned AS o
    INNER JOIN dbo.customers_cleaned AS c
    ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp IS NOT NULL
),
CustomerCohorts AS (
    SELECT
        customer_unique_id,
        MIN(purchase_month) AS cohort_month
    FROM CustomerPurchases
    GROUP BY customer_unique_id
),
CohortActivity AS (
    SELECT DISTINCT
        p.customer_unique_id,
        c.cohort_month,
        DATEDIFF(MONTH,c.cohort_month,p.purchase_month) AS month_number
    FROM CustomerPurchases AS p
    INNER JOIN CustomerCohorts AS c
    ON p.customer_unique_id = c.customer_unique_id
),
CohortCounts AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT CASE WHEN month_number = 0
            THEN customer_unique_id END) AS cohort_size,
        COUNT(DISTINCT CASE WHEN month_number = 1
            THEN customer_unique_id END) AS month_1_customers,
        COUNT(DISTINCT CASE WHEN month_number = 2
            THEN customer_unique_id END) AS month_2_customers
    FROM CohortActivity
    GROUP BY cohort_month
)
SELECT
    CONVERT(CHAR(7), cohort_month, 120) AS cohort_month,
    cohort_size,
    month_1_customers,
    month_2_customers,
    CAST(100.0 * month_1_customers / NULLIF(cohort_size, 0)AS DECIMAL(10, 2)) AS month_1_retention_pct,
    CAST(100.0 * month_2_customers / NULLIF(cohort_size, 0)AS DECIMAL(10, 2)) AS month_2_retention_pct
FROM CohortCounts
ORDER BY cohort_month;



-- Query 9: Full monthly cohort retention percentages
-- Only delivered orders are included
-- Each customer is counted once per purchase month

WITH CustomerPurchases AS (
    SELECT DISTINCT
        c.customer_unique_id,
        DATEFROMPARTS(YEAR(o.order_purchase_timestamp),MONTH(o.order_purchase_timestamp),1) AS purchase_month
    FROM dbo.orders_cleaned AS o
    INNER JOIN dbo.customers_cleaned AS c
    ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp IS NOT NULL
),
CustomerCohorts AS (
    SELECT
        customer_unique_id,
        MIN(purchase_month) AS cohort_month
    FROM CustomerPurchases
    GROUP BY customer_unique_id
),
CohortActivity AS (
    SELECT DISTINCT
        p.customer_unique_id,
        c.cohort_month,
        DATEDIFF(MONTH,c.cohort_month,p.purchase_month) AS month_number
    FROM CustomerPurchases AS p
    INNER JOIN CustomerCohorts AS c
    ON p.customer_unique_id = c.customer_unique_id
),
CohortSizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM CustomerCohorts
    GROUP BY cohort_month
)
SELECT
    CONVERT(CHAR(7), a.cohort_month, 120) AS cohort_month,
    a.month_number,
    s.cohort_size,
    COUNT(DISTINCT a.customer_unique_id) AS active_customers,
    CAST(100.0 * COUNT(DISTINCT a.customer_unique_id)
        / NULLIF(s.cohort_size, 0)AS DECIMAL(10, 2)) AS retention_pct
FROM CohortActivity AS a
INNER JOIN CohortSizes AS s
ON a.cohort_month = s.cohort_month
GROUP BY
    a.cohort_month,
    a.month_number,
    s.cohort_size
ORDER BY
    a.cohort_month,
    a.month_number;



-- Query 10:  Final validation
-- Check the observation period for delivered purchases

SELECT
    MIN(order_purchase_timestamp) AS first_purchase_date,
    MAX(order_purchase_timestamp) AS last_purchase_date,
    COUNT(DISTINCT order_id) AS delivered_orders
FROM dbo.orders_cleaned
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL;



-- Query 11:  Average Orders per Customer
-- Count delivered orders for each unique customer
-- Then calculate the average purchase frequency

WITH CustomerOrders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM dbo.orders_cleaned AS o
    INNER JOIN dbo.customers_cleaned AS c
    ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND c.customer_unique_id IS NOT NULL
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(total_orders) AS total_orders,
    CAST(AVG(CAST(total_orders AS FLOAT))AS DECIMAL(10,2)) AS avg_orders_per_customer
FROM CustomerOrders;

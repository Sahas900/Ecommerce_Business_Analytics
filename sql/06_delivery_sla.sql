
-- Query 1: Check delivered orders and available delivery dates

SELECT
    COUNT(*) AS total_delivered_orders,

    COUNT(order_purchase_timestamp) AS orders_with_purchase_date,

    COUNT(order_delivered_customer_date) AS orders_with_delivery_date,

    COUNT(order_estimated_delivery_date) AS orders_with_estimated_date,

    SUM(CASE
        WHEN order_purchase_timestamp IS NOT NULL
         AND order_delivered_customer_date IS NOT NULL
         AND order_estimated_delivery_date IS NOT NULL
        THEN 1 ELSE 0 
        END) AS valid_orders_for_sla

FROM dbo.orders_cleaned

WHERE order_status = 'delivered';



-- Query 2: Calculate actual delivery time for delivered orders
-- Exclude orders with missing delivery dates

SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_customer_date,
    DATEDIFF(DAY,order_purchase_timestamp,order_delivered_customer_date) AS delivery_days

FROM dbo.orders_cleaned

WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
ORDER BY delivery_days DESC;


-- Query 3: Calculate on-time and late delivery performance
-- Use only delivered orders with valid dates

SELECT
    COUNT(*) AS total_valid_deliveries,

    SUM(CASE
        WHEN order_delivered_customer_date <= order_estimated_delivery_date
        THEN 1 ELSE 0
    END) AS on_time_orders,

    SUM(CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date
        THEN 1 ELSE 0
    END) AS late_orders,

    CAST(
        100.0 * SUM(CASE
            WHEN order_delivered_customer_date <= order_estimated_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS on_time_percentage,

    CAST(
        100.0 * SUM(CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS late_percentage

FROM dbo.orders_cleaned

WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;


-- Query 4: Calculate median and 90th percentile delivery time
-- Use precise delivery duration in days

WITH DeliveryTimes AS (
    SELECT
        order_id,
        DATEDIFF(SECOND,order_purchase_timestamp,order_delivered_customer_date) / 86400.0 AS delivery_days
    FROM dbo.orders_cleaned
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_customer_date >= order_purchase_timestamp
),
DeliveryPercentiles AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) OVER () AS median_delivery_days,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days) OVER () AS p90_delivery_days
    FROM DeliveryTimes
)
SELECT DISTINCT
    CAST(median_delivery_days AS DECIMAL(10,2)) AS median_delivery_days,
    CAST(p90_delivery_days AS DECIMAL(10,2)) AS p90_delivery_days
FROM DeliveryPercentiles;


-- Query 5: Analyze late delivery rate by customer state
-- Include states with at least 100 valid deliveries

SELECT
    c.customer_state,
    COUNT(*) AS total_deliveries,
    SUM(CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date
        THEN 1 ELSE 0
        END) AS late_deliveries,
    CAST(100.0 * SUM(CASE
            WHEN o.order_delivered_customer_date >
                 o.order_estimated_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0) AS DECIMAL(10,2)
    ) AS late_rate_pct
FROM dbo.orders_cleaned AS o
INNER JOIN dbo.customers_cleaned AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND c.customer_state IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 100
ORDER BY late_rate_pct DESC;


-- Query 6: Calculate monthly late-delivery performance
-- Group orders by purchase month

SELECT
    CONVERT(CHAR(7), order_purchase_timestamp, 120) AS purchase_month,
    COUNT(*) AS total_deliveries,
    SUM(CASE
        WHEN order_delivered_customer_date >
             order_estimated_delivery_date
        THEN 1 ELSE 0
    END) AS late_deliveries,
    CAST(
        100.0 * SUM(CASE
            WHEN order_delivered_customer_date >
                 order_estimated_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0) AS DECIMAL(10,2)
    ) AS late_rate_pct
FROM dbo.orders_cleaned
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY CONVERT(CHAR(7), order_purchase_timestamp, 120)
ORDER BY purchase_month;


-- Query 7: Calculate late delivery rate by seller
-- Count each order only once per seller
-- Include sellers with at least 50 delivered orders

WITH SellerOrders AS (
    SELECT DISTINCT
        i.seller_id,
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM dbo.orders_cleaned AS o
    INNER JOIN dbo.items_cleaned AS i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    seller_id,
    COUNT(*) AS total_deliveries,
    SUM(CASE
        WHEN order_delivered_customer_date >
             order_estimated_delivery_date
        THEN 1 ELSE 0
    END) AS late_deliveries,
    CAST(
        100.0 * SUM(CASE
            WHEN order_delivered_customer_date >
                 order_estimated_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS late_rate_pct
FROM SellerOrders
GROUP BY seller_id
HAVING COUNT(*) >= 50
ORDER BY late_rate_pct DESC;



-- Query 8: Analyze late delivery rates by product category
-- Count each order once per category
-- Include categories with at least 100 deliveries

WITH CategoryOrders AS (
    SELECT DISTINCT
        p.product_category_name,
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM dbo.orders_cleaned AS o
    INNER JOIN dbo.items_cleaned AS i
    ON o.order_id = i.order_id
    INNER JOIN dbo.products_cleaned AS p
    ON i.product_id = p.product_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND p.product_category_name IS NOT NULL
)
SELECT
    product_category_name,
    COUNT(*) AS total_deliveries,
    SUM(CASE
        WHEN order_delivered_customer_date >
             order_estimated_delivery_date
        THEN 1 ELSE 0
    END) AS late_deliveries,
    CAST(
        100.0 * SUM(CASE
            WHEN order_delivered_customer_date >
                 order_estimated_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS late_rate_pct
FROM CategoryOrders
GROUP BY product_category_name
HAVING COUNT(*) >= 100
ORDER BY late_rate_pct DESC;



-- Query 9: Analyze delivery time distribution
-- Include only delivered orders with valid dates

WITH DeliveryTimes AS (
    SELECT
        order_id,
        DATEDIFF(SECOND,order_purchase_timestamp,order_delivered_customer_date) / 86400.0 AS delivery_days
    FROM dbo.orders_cleaned
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_customer_date >= order_purchase_timestamp
),
DeliveryGroups AS (
    SELECT
        CASE
            WHEN delivery_days <= 5 THEN '0-5 days'
            WHEN delivery_days <= 10 THEN '6-10 days'
            WHEN delivery_days <= 15 THEN '11-15 days'
            WHEN delivery_days <= 20 THEN '16-20 days'
            WHEN delivery_days <= 30 THEN '21-30 days'
            ELSE 'Over 30 days'
        END AS delivery_range,
        CASE
            WHEN delivery_days <= 5 THEN 1
            WHEN delivery_days <= 10 THEN 2
            WHEN delivery_days <= 15 THEN 3
            WHEN delivery_days <= 20 THEN 4
            WHEN delivery_days <= 30 THEN 5
            ELSE 6
        END AS sort_order
    FROM DeliveryTimes
)
SELECT
    delivery_range,
    COUNT(*) AS total_orders
FROM DeliveryGroups
GROUP BY delivery_range, sort_order
ORDER BY sort_order;



-- Query 10: Compare customer review scores for on-time and late orders
-- Average multiple reviews per order to avoid duplicate orders

WITH OrderReviews AS (
    SELECT
        order_id,
        AVG(CAST(review_score AS FLOAT)) AS avg_review_score
    FROM dbo.reviews_cleaned
    WHERE review_score IS NOT NULL
    GROUP BY order_id
)
SELECT
    CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date
        THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,
    COUNT(*) AS total_reviewed_orders,
    CAST(AVG(r.avg_review_score) AS DECIMAL(10,2)) AS avg_review_score
FROM dbo.orders_cleaned AS o
INNER JOIN OrderReviews AS r
ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY
    CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date
        THEN 'Late'
        ELSE 'On Time'
    END;



-- Query 11: Prepare order-level delivery dataset for Power BI
-- One row per delivered order with valid dates

WITH OrderReviews AS (
    SELECT
        order_id,
        AVG(CAST(review_score AS FLOAT)) AS avg_review_score
    FROM dbo.reviews_cleaned
    WHERE review_score IS NOT NULL
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_state,
    o.order_purchase_timestamp,
    CONVERT(CHAR(7), o.order_purchase_timestamp, 120) AS purchase_month,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATEDIFF(SECOND,o.order_purchase_timestamp,o.order_delivered_customer_date) / 86400.0 AS delivery_days,
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN 'Late'
        ELSE 'On Time'
    END AS delivery_status,
    r.avg_review_score
FROM dbo.orders_cleaned AS o
INNER JOIN dbo.customers_cleaned AS c
ON o.customer_id = c.customer_id
LEFT JOIN OrderReviews AS r
ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND o.order_delivered_customer_date >= o.order_purchase_timestamp;

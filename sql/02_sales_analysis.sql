-- Query 1: Orders by Status
-- One row per order status; counts orders across all statuses

SELECT
    order_status,
    COUNT(*) AS total_orders
FROM dbo.orders_cleaned
GROUP BY order_status
ORDER BY total_orders DESC;

GO

-- Query 2: Total Sales Revenue
-- One summary row; delivered-order item revenue (BRL), excluding freight

SELECT
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.orders_cleaned AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

GO


-- Query 3: Average Order Value
-- One summary row; delivered-order item revenue divided by distinct delivered orders containing items

SELECT
    ROUND(SUM(oi.price) / COUNT(DISTINCT oi.order_id), 2) AS average_order_value
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.orders_cleaned AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';

GO


-- Query 4: Total Unique Customers
-- One summary row; distinct customer_unique_id values with delivered orders

SELECT
    COUNT(DISTINCT c.customer_unique_id) AS total_customers
FROM dbo.customers_cleaned AS c
INNER JOIN dbo.orders_cleaned AS o
ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered';

GO


-- Query 5: Monthly Delivered Orders
-- One row per purchase year/month; number of orders eventually delivered

SELECT
    YEAR(order_purchase_timestamp) AS order_year,
    MONTH(order_purchase_timestamp) AS order_month,
    COUNT(*) AS total_orders
FROM dbo.orders_cleaned
WHERE order_status = 'delivered'
GROUP BY
    YEAR(order_purchase_timestamp),
    MONTH(order_purchase_timestamp)
ORDER BY
    order_year,
    order_month;

GO


-- Query 6: Top 10 Best-Selling Products
-- One row per product (top 10); delivered item rows counted as units sold

SELECT TOP 10
    oi.product_id,
    COUNT(*) AS total_units_sold
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.orders_cleaned AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id
ORDER BY total_units_sold DESC;

GO


-- Query 7: Top 10 Categories by Revenue
-- One row per product category (top 10); delivered-item revenue, excluding freight

SELECT TOP 10
    p.product_category_name,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.products_cleaned AS p
ON oi.product_id = p.product_id
INNER JOIN dbo.orders_cleaned AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name
ORDER BY total_revenue DESC;

GO


-- Query 8: Top 10 Sellers by Revenue
-- One row per seller (top 10); delivered-item revenue, excluding freight

SELECT TOP 10
    oi.seller_id,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.orders_cleaned AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id
ORDER BY total_revenue DESC;

GO


-- Query 9: Monthly Sales Revenue
-- One row per purchase year/month; delivered-order item revenue (BRL), excluding freight

SELECT
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    ROUND(SUM(oi.price), 2) AS monthly_revenue
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.orders_cleaned AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)
ORDER BY
    order_year,
    order_month;

GO


-- Query 10: Month-over-Month Revenue Growth
-- One row per purchase year/month; revenue, previous month revenue, and percentage change
-- The first month has NULL previous-month revenue and growth; NULLIF protects division by zero


WITH MonthlySales AS (
    SELECT
        YEAR(o.order_purchase_timestamp) AS order_year,
        MONTH(o.order_purchase_timestamp) AS order_month,
        SUM(oi.price) AS revenue
    FROM dbo.items_cleaned AS oi
    INNER JOIN dbo.orders_cleaned AS o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
),
RevenueComparison AS (
    SELECT
        order_year,
        order_month,
        revenue,
        LAG(revenue) OVER (
            ORDER BY order_year, order_month
        ) AS previous_month_revenue
    FROM MonthlySales
)
SELECT
    order_year,
    order_month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND((revenue - previous_month_revenue) * 100.0
        / NULLIF(previous_month_revenue, 0),2) AS mom_growth_percentage
FROM RevenueComparison
ORDER BY order_year, order_month;

GO


-- Query 11: Repeat Customers Analysis
-- One row per repeat customer_unique_id; counts delivered orders (more than one)

SELECT
    c.customer_unique_id,
    COUNT(o.order_id) AS total_orders
FROM dbo.customers_cleaned AS c
INNER JOIN dbo.orders_cleaned AS o
ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
HAVING COUNT(o.order_id) > 1
ORDER BY total_orders DESC;

GO


-- Query 12: Repeat Customer Rate
-- One summary row; repeat customers / customers with delivered orders * 100


WITH CustomerOrders AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS total_orders
    FROM dbo.customers_cleaned AS c
    INNER JOIN dbo.orders_cleaned AS o
    ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)AS repeat_customers,
    ROUND(SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2) AS repeat_customer_rate
FROM CustomerOrders;

GO


-- Query 13: Product Item Price Segmentation
-- One row per item-price segment; counts delivered-order item rows, not orders
-- Low: < 100 BRL; Medium: 100 through 500 BRL; High: > 500 BRL

SELECT
    CASE WHEN price < 100 THEN 'Low Value'
         WHEN price BETWEEN 100 AND 500 THEN 'Medium Value'
         ELSE 'High Value'
    END AS value_segment,
    COUNT(*) AS total_items
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.orders_cleaned AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    CASE WHEN price < 100 THEN 'Low Value'
         WHEN price BETWEEN 100 AND 500 THEN 'Medium Value'
         ELSE 'High Value'
    END;

GO


-- Query 14: Order Value Segmentation
-- One row per order-value segment; each delivered order is aggregated before classification
-- Low: < 100 BRL; Medium: 100 to < 500 BRL; High: >= 500 BRL

WITH OrderSales AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS order_value
    FROM dbo.items_cleaned AS oi
    INNER JOIN dbo.orders_cleaned AS o
    ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
)
SELECT
    CASE WHEN order_value < 100 THEN 'Low Value'
         WHEN order_value < 500 THEN 'Medium Value'
         ELSE 'High Value'
    END AS order_segment,
    COUNT(*) AS total_orders
FROM OrderSales
GROUP BY
    CASE WHEN order_value < 100 THEN 'Low Value'
         WHEN order_value < 500 THEN 'Medium Value'
         ELSE 'High Value'
    END
ORDER BY total_orders DESC;

GO


-- Query 15: Average Delivery Time
-- One summary row; average whole-day DATEDIFF between purchase and delivery timestamps
-- DATEDIFF(DAY) counts day boundaries crossed, not exact elapsed 24-hour periods

SELECT
    ROUND(AVG(CAST(DATEDIFF(DAY,order_purchase_timestamp,
    order_delivered_customer_date) AS FLOAT)), 2) AS average_delivery_days
FROM dbo.orders_cleaned
WHERE order_status = 'delivered'
AND order_delivered_customer_date IS NOT NULL;

GO


-- Query 16: On-Time vs Late Deliveries
-- One row per delivery status; compares full delivery and estimated timestamps
-- Excludes delivered orders with missing actual or estimated delivery dates

SELECT
    CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date
         THEN 'On Time'
         ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS total_orders
FROM dbo.orders_cleaned
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL
GROUP BY
    CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date
         THEN 'On Time'
         ELSE 'Late'
    END;

GO


-- Query 17: On-Time Delivery Percentage
-- One summary row; percentage on time using full timestamp comparison
-- Excludes delivered orders with missing actual or estimated delivery dates

SELECT
COUNT(*) AS total_deliveries,
SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date
         THEN 1
         ELSE 0
    END) AS on_time_deliveries,
    ROUND(SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date
                   THEN 1
                   ELSE 0
              END) * 100.0 / COUNT(*),2) AS on_time_percentage
FROM dbo.orders_cleaned
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL;

GO


-- Query 18: Top 10 States by Sales Revenue
-- One row per customer state (top 10); delivered-order item revenue, excluding freight

SELECT TOP 10
    c.customer_state,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.orders_cleaned AS o
ON oi.order_id = o.order_id
INNER JOIN dbo.customers_cleaned AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;

GO


-- Query 19: Payment Method Analysis
-- One row per payment type; all order statuses included
-- Counts payment records, not distinct orders; payment_value may include freight

SELECT
    payment_type,
    COUNT(*) AS total_transactions,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM dbo.payments_cleaned
GROUP BY payment_type
ORDER BY total_transactions DESC;

GO


-- Query 20: Top 10 Products by Revenue
-- One row per product (top 10); delivered-order item revenue, excluding freight

SELECT TOP 10
    oi.product_id,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM dbo.items_cleaned AS oi
INNER JOIN dbo.orders_cleaned AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id
ORDER BY total_revenue DESC;

GO


-- Query 21: Seller Revenue Ranking using RANK()
-- One row per seller; revenue rank across sellers using RANK() (ties share a rank)

WITH SellerSales AS (
    SELECT
        oi.seller_id,
        ROUND(SUM(oi.price), 2) AS total_revenue
    FROM dbo.items_cleaned AS oi
    INNER JOIN dbo.orders_cleaned AS o
    ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT
    seller_id,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS seller_rank
FROM SellerSales
ORDER BY seller_rank;

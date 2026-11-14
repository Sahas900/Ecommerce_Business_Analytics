# Advanced SQL Sales & Revenue Analysis

**Project:** E-Commerce Business Intelligence & Sales Analytics  
**Dataset:** Olist Brazilian E-Commerce Dataset (cleaned tables)  
**Database:** Microsoft SQL Server (SSMS)  
**Currency:** Brazilian Real (BRL, R$)

## Scope and metric definitions

Unless otherwise specified, revenue and order-value measures use **delivered orders only** and sum `order_items.price` (product sales value **excluding freight**). This is not payment receipts or net profit. Unique buyers use `customer_unique_id`. Repeat buyers are customers with **more than one delivered order**. Delivery punctuality uses records with nonmissing actual and estimated delivery timestamps. The dataset is historical; findings do not describe current Olist performance.

## Key performance indicators

| KPI | Result |
|---|---:|
| All orders (all statuses) | 99,441 |
| Delivered orders | 96,478 (97.02% of all orders) |
| Delivered-order product sales value | R$ 13,221,498.11 |
| Average product sales value per delivered order | R$ 137.04 |
| Unique customers with delivered orders | 93,358 |
| Repeat customers with 2+ delivered orders | 2,801 |
| Repeat-customer rate | 3.00% |
| Deliveries with both required dates | 96,470 |
| On-time deliveries | 88,644 |
| On-time delivery rate | 91.89% |

## Five business findings

### 1. Delivered orders account for most order records
Of 99,441 recorded orders, 96,478 have `delivered` status (about **97.02%**). This is a historical status distribution, not a real-time delivery success metric. Product sales value for these delivered orders totals **R$ 13.22 million**; the corresponding average is **R$ 137.04 per order**.

**Business implication:** Monitor order status alongside sales KPIs so canceled and incomplete orders do not distort delivered-order performance.

### 2. Health & Beauty is the leading product category by revenue
The category `beleza_saude` (Health & Beauty) leads the top-10 category export at **R$ 1,233,131.72**. Next are `relogios_presentes` (Watches & Gifts), **R$ 1,166,176.98**, and `cama_mesa_banho` (Bed, Bath & Table), **R$ 1,023,434.76**. These are product sales values for delivered orders, excluding freight.

**Business implication:** Prioritize category-specific inventory, merchandising, and promotional tests for high-contributing categories; check margins before making budget decisions.

### 3. Monthly sales rose strongly during the main observed period, with fluctuations
The highest monthly delivered-order product revenue in the exported data was **November 2017: R$ 987,765.37**, up **52.37%** from October 2017 (**R$ 648,247.65**). Revenue then fell **26.50%** in December 2017 to **R$ 726,033.19**. The export covers sparse early observations in 2016 and months through August 2018.

**Business implication:** Investigate seasonality, promotional events, and demand spikes before planning stock and staffing. Extremely high early MoM percentages are driven by tiny previous-month revenue bases and should not be treated as typical growth.

### 4. Repeat purchasing is limited in this dataset
Of **93,358** distinct customers with delivered orders, **2,801** placed more than one delivered order: a **3.00% repeat-customer rate**.

**Business implication:** Explore post-purchase engagement, targeted reactivation, and category-specific repeat-purchase campaigns. The dataset does not establish why repeat purchasing is low, and the observation window limits how much repeat behavior can be seen.

### 5. Most recorded deliveries meet their estimated deadline
Among **96,470** delivered orders with both actual and estimated delivery timestamps, **88,644 (91.89%)** arrived on or before the estimated timestamp; **7,826 (8.11%)** arrived later. Eight delivered orders were excluded from this metric because at least one required date was missing.

**Business implication:** Analyze late deliveries by region, seller, and shipping characteristics to identify where logistics improvements may have the greatest effect.

## Methodology and quality notes

- Sales metrics join order items to orders using `order_id`, filtering `order_status = 'delivered'`.
- Do **not** directly join raw `order_items` and `order_payments` when summing revenue: both can have multiple rows per order and cause multiplication of amounts. Aggregate each child table by `order_id` first if a comparison is needed.
- The month-over-month query uses `LAG()` over chronological year/month ordering. The first month has no prior observation, so growth is undefined. If calendar months are missing, `LAG()` compares with the previous **observed** month rather than necessarily the immediately preceding calendar month; a calendar table is needed for strict calendar-month MoM.
- Category labels in the CSV are Portuguese names; English translations above are descriptive translations.
- The supplied CSV exports did not include column headers. Their columns were interpreted from the SQL queries: `top_10_categories.csv` = category, revenue; `monthly_revenue_growth.csv` = year, month, monthly revenue, previous observed month's revenue, MoM growth percent.
- Order-value segmentation thresholds and seller rankings are exploratory; conclusions about profitability require cost and margin data.

## Supporting files

- `sql/02_sales_analysis.sql` — SQL analysis and seller ranking query (verify the final saved file contains the added `RANK()` query)
- `reports/monthly_sales_revenue.csv`
- `reports/monthly_revenue_growth.csv`
- `reports/repeat_customer_rate.csv`
- `reports/top_10_categories.csv`
- `reports/on_time_delivery.csv`

## Interview-ready summary

> I cleaned and imported nine Olist e-commerce tables into SQL Server, then used joins, aggregations, CTEs, `CASE`, `LAG`, and `RANK` to analyze delivered-order sales, customer repeat purchasing, category performance, monthly trends, and delivery reliability. I documented KPI definitions carefully to avoid double-counting revenue when joining one-to-many tables.

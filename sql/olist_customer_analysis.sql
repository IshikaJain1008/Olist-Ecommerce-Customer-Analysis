/*
===============================================================================
PROJECT: Olist E-commerce Customer Analysis
DATABASE: MySQL 8.0+
SCHEMA: olist_analytics

PURPOSE
This script answers business questions about order performance, repeat buying,
customer retention, customer value and RFM-based customer segments.

HOW TO USE
1. Make sure the final tables have been loaded into the olist_analytics schema.
2. Run this script section by section in MySQL Workbench.
3. The script creates three reusable views for the RFM analysis:
      vw_customer_rfm
      vw_customer_rfm_scored
      vw_customer_rfm_segments
4. Run the analysis queries below those view definitions.

METRIC DEFINITIONS / SCOPE
- Customer identity: customer_unique_id (not customer_id).
- Customer retention and RFM: delivered orders only.
- Cohort month: month of the customer's first delivered order.
- Recency: days between the RFM reference date and the customer's last
  delivered purchase date.
- RFM reference date: one day after the latest delivered purchase date.
- Frequency: number of distinct delivered orders.
- Monetary: sum of order_items.price for delivered orders; freight is excluded.
- Currency: Brazilian Real (R$), as represented in the source dataset.
- Dataset period observed in this analysis: September 2016 to August 2018.

IMPORTANT
This is historical dataset analysis. Recency is relative to the dataset's
reference date, not the current date. RFM segment rules are project-defined
business rules, not universal industry standards.
===============================================================================
*/

USE olist_analytics;

/* ---------------------------------------------------------------------------
BUSINESS QUESTION 1
How are orders distributed across order statuses?

WHY THIS MATTERS
Provides a high-level view of order fulfilment and non-delivered orders.
*/
SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS order_percentage
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

/* INTERPRETATION FROM THIS PROJECT'S RUN
96,478 orders were delivered (approximately 97.02% of 99,441 orders).
The remaining orders were distributed across shipped, canceled, unavailable,
invoiced, processing, created and approved statuses.
*/


/* ---------------------------------------------------------------------------
BUSINESS QUESTION 2
How many customers make only one delivered purchase, and how many return?

WHY THIS MATTERS
Repeat purchase rate is a basic indicator of customer retention.
Use customer_unique_id because customer_id is associated with an order-level
customer record, while customer_unique_id identifies the actual customer.
*/
WITH customer_order_frequency AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_order_count
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN delivered_order_count = 1 THEN 'One-time customers'
        ELSE 'Repeat customers'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_percentage
FROM customer_order_frequency
GROUP BY customer_type
ORDER BY customer_count DESC;

/* INTERPRETATION FROM THIS PROJECT'S RUN
One-time customers: 90,557 (approximately 97.00%).
Repeat customers: 2,801 (approximately 3.00%).
This indicates that most customers in this historical dataset did not place
another delivered order.
*/


/* ---------------------------------------------------------------------------
BUSINESS QUESTION 3
How does customer retention change across monthly acquisition cohorts?

WHY THIS MATTERS
Groups customers by the month of their first delivered purchase and measures
how many of them purchase again in later calendar months.
Month 0 is the first purchase month. Retention is not cumulative: a customer
may skip a month and return in a later month.
*/
WITH delivered_customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        STR_TO_DATE(
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01'),
            '%Y-%m-%d'
        ) AS activity_month
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
),
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase_timestamp
    FROM delivered_customer_orders
    GROUP BY customer_unique_id
),
customer_cohorts AS (
    SELECT
        customer_unique_id,
        STR_TO_DATE(
            DATE_FORMAT(first_purchase_timestamp, '%Y-%m-01'),
            '%Y-%m-%d'
        ) AS cohort_month
    FROM first_purchase
),
cohort_activity AS (
    SELECT DISTINCT
        dco.customer_unique_id,
        cc.cohort_month,
        dco.activity_month,
        TIMESTAMPDIFF(MONTH, cc.cohort_month, dco.activity_month) AS month_number
    FROM delivered_customer_orders AS dco
    INNER JOIN customer_cohorts AS cc
        ON dco.customer_unique_id = cc.customer_unique_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),
monthly_retention AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, month_number
)
SELECT
    DATE_FORMAT(mr.cohort_month, '%Y-%m') AS cohort_month,
    mr.month_number,
    cs.cohort_size,
    mr.active_customers,
    ROUND(100.0 * mr.active_customers / cs.cohort_size, 2) AS retention_percentage
FROM monthly_retention AS mr
INNER JOIN cohort_sizes AS cs
    ON mr.cohort_month = cs.cohort_month
ORDER BY mr.cohort_month, mr.month_number;

/* INTERPRETATION
Compare Month 1, Month 2 and later retention percentages across cohorts.
Newer cohorts have fewer observable months because the dataset ends in
August 2018 (right-censoring). Low retention shows limited repeat activity,
but this query alone cannot explain why customers did not return.
*/


/* ---------------------------------------------------------------------------
RFM FOUNDATION
Create reusable views so that the RFM logic is defined once and can be used
by multiple analysis queries and, later, by Power BI.

RFM SCORING
- Recency: NTILE(5) ordered by recency_days DESC; 5 means most recent.
- Frequency: custom business score based on observed purchase frequency:
      1 order  -> score 1
      2 orders -> score 3
      3+ orders -> score 5
- Monetary: NTILE(5) ordered by monetary_value ASC; 5 means highest spending.

NTILE NOTE
NTILE creates similarly sized buckets and can split customers with identical
Recency or Monetary values across adjacent buckets. This is a known limitation
of percentile-based scoring and should be documented when interpreting scores.
*/

CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
),
order_values AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    GROUP BY oi.order_id
),
reference_date AS (
    SELECT
        DATE_ADD(DATE(MAX(order_purchase_timestamp)), INTERVAL 1 DAY) AS rfm_reference_date
    FROM delivered_orders
)
SELECT
    d.customer_unique_id,
    DATEDIFF(
        rd.rfm_reference_date,
        DATE(MAX(d.order_purchase_timestamp))
    ) AS recency_days,
    COUNT(DISTINCT d.order_id) AS frequency,
    ROUND(SUM(ov.product_revenue), 2) AS monetary_value
FROM delivered_orders AS d
INNER JOIN order_values AS ov
    ON d.order_id = ov.order_id
CROSS JOIN reference_date AS rd
GROUP BY d.customer_unique_id, rd.rfm_reference_date;

CREATE OR REPLACE VIEW vw_customer_rfm_scored AS
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary_value,
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
    CASE
        WHEN frequency = 1 THEN 1
        WHEN frequency = 2 THEN 3
        ELSE 5
    END AS f_score,
    NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
FROM vw_customer_rfm;

CREATE OR REPLACE VIEW vw_customer_rfm_segments AS
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary_value,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 3 AND m_score >= 4
            THEN 'Champions'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 4
            THEN 'Cannot Lose Them'
        WHEN r_score >= 3 AND f_score >= 3
            THEN 'Loyal Customers'
        WHEN r_score >= 3 AND f_score = 1 AND m_score = 5
            THEN 'Big Spenders'
        WHEN r_score >= 4 AND f_score = 1 AND m_score >= 3
            THEN 'Potential Loyalists'
        WHEN r_score = 5 AND f_score = 1 AND m_score <= 2
            THEN 'Recent Customers'
        WHEN r_score <= 2 AND f_score >= 3
            THEN 'At Risk'
        WHEN r_score <= 2 AND f_score = 1 AND m_score <= 2
            THEN 'Hibernating'
        WHEN r_score <= 2 AND f_score = 1 AND m_score >= 3
            THEN 'Needs Attention'
        ELSE 'Promising'
    END AS customer_segment
FROM vw_customer_rfm_scored;


/* ---------------------------------------------------------------------------
BUSINESS QUESTION 4
What does the overall RFM customer profile look like?

WHY THIS MATTERS
Checks the range and average of Recency, Frequency and Monetary values before
interpreting customer scores and segments.
*/
SELECT
    COUNT(*) AS total_customers,
    MIN(recency_days) AS min_recency_days,
    MAX(recency_days) AS max_recency_days,
    ROUND(AVG(recency_days), 2) AS avg_recency_days,
    MIN(frequency) AS min_frequency,
    MAX(frequency) AS max_frequency,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(MIN(monetary_value), 2) AS min_monetary_value,
    ROUND(MAX(monetary_value), 2) AS max_monetary_value,
    ROUND(AVG(monetary_value), 2) AS avg_monetary_value
FROM vw_customer_rfm;

/* REFERENCE RESULTS FROM THIS PROJECT'S RUN
Customers: 93,358
Recency: minimum 1 day, maximum 714 days, average 238.48 days.
Frequency: minimum 1, maximum 15, average 1.03 orders.
Monetary: minimum R$0.85, maximum R$13,440.00, average R$141.62.
*/


/* ---------------------------------------------------------------------------
BUSINESS QUESTION 5
How many customers fall into each RFM segment?

WHY THIS MATTERS
Shows the size of each customer group and gives a starting point for deciding
which groups need retention, reactivation or loyalty initiatives.
*/
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_percentage,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(AVG(monetary_value), 2) AS avg_monetary_value
FROM vw_customer_rfm_segments
GROUP BY customer_segment
ORDER BY customer_count DESC;

/* INTERPRETATION FROM THIS PROJECT'S RUN
Largest segments:
- Promising: 21,845 customers (23.40%).
- Needs Attention: 21,084 customers (22.58%).
- Hibernating: 15,268 customers (16.35%).
- Potential Loyalists: 14,831 customers (15.89%).
- Big Spenders: 10,146 customers (10.87%).
Champions: 932 customers (1.00%).
The four repeat-customer segments (Champions, Loyal Customers,
Cannot Lose Them and At Risk) total 2,801 customers (3.00%).
*/


/* ---------------------------------------------------------------------------
BUSINESS QUESTION 6
Which RFM segments contribute the most product revenue?

WHY THIS MATTERS
Customer count alone does not show the financial importance of a segment.
This query compares segment size, revenue contribution and delivered orders.
*/
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(monetary_value), 2) AS total_product_revenue,
    ROUND(
        100.0 * SUM(monetary_value) / SUM(SUM(monetary_value)) OVER (),
        2
    ) AS revenue_percentage,
    ROUND(AVG(monetary_value), 2) AS avg_customer_value,
    SUM(frequency) AS total_delivered_orders
FROM vw_customer_rfm_segments
GROUP BY customer_segment
ORDER BY total_product_revenue DESC;

/* INTERPRETATION FROM THIS PROJECT'S RUN
- Needs Attention: R$4,463,131.26 (33.76% of product revenue).
- Big Spenders: R$4,025,709.98 (30.45%).
- Potential Loyalists: R$1,697,455.15 (12.84%).
- Promising: R$1,404,322.70 (10.62%).
Needs Attention and Big Spenders together contribute 64.21% of product revenue.
One-time customer segments contribute approximately 94.48% of product revenue;
repeat-customer segments contribute approximately 5.52%.
*/


/* ---------------------------------------------------------------------------
BUSINESS QUESTION 7
Do the RFM views reconcile with the known customer and order totals?

WHY THIS MATTERS
Final validation checks that each customer appears once in the RFM output and
that the total frequency agrees with the delivered-order count.
*/
SELECT
    COUNT(*) AS total_customer_rows,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    SUM(frequency) AS total_delivered_orders,
    ROUND(SUM(monetary_value), 2) AS total_product_revenue
FROM vw_customer_rfm;

/* EXPECTED RECONCILIATION FROM THIS PROJECT'S RUN
- total_customer_rows: 93,358
- unique_customers: 93,358
- total_delivered_orders: 96,478
- total_product_revenue: R$13,221,498.11
*/


/* ---------------------------------------------------------------------------
FINAL BUSINESS CONCLUSIONS

1. The dataset contains 99,441 orders, of which 96,478 (about 97.02%) were
   delivered.
2. Of 93,358 customers with delivered orders, 90,557 (about 97%) made one
   delivered purchase and 2,801 (about 3%) made repeat purchases.
3. Cohort analysis indicates weak repeat purchasing across many cohorts.
   Recent cohorts have shorter observation windows because the dataset ends
   in August 2018.
4. Needs Attention and Big Spenders together account for 64.21% of product
   revenue. These are important groups for targeted customer engagement.
5. Potential Loyalists represent 15.89% of customers and are candidates for
   second-purchase campaigns.
6. Champions represent approximately 1% of customers, highlighting the small
   size of the strongest repeat-customer segment.

RECOMMENDED BUSINESS ACTIONS
- Prioritise personalised win-back campaigns for Needs Attention customers.
- Encourage Big Spenders to make a second purchase through relevant product
  recommendations and complementary-product offers.
- Use second-purchase incentives to develop Potential Loyalists.
- Test loyalty benefits and referral initiatives with Champions and Loyal
  Customers.
- Use low-cost reactivation tests for Hibernating customers before investing
  in broad campaigns.

LIMITATIONS
- The dataset is historical (September 2016 to August 2018); findings should
  not be presented as current marketplace behaviour.
- RFM recency is measured relative to 30 August 2018, not today's date.
- Monetary value includes item price and excludes freight.
- RFM segments depend on the scoring and business rules selected for this
  project. Different thresholds may produce different segment sizes.
- NTILE can split tied Recency or Monetary values across adjacent buckets.
- Cohort retention describes observed purchasing activity; it does not explain
  the reasons customers did not return.

END OF ANALYSIS
===============================================================================
*/

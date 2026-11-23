# Olist E-commerce Customer Analysis

## Project Overview

This project analyses customer purchasing behaviour, retention patterns and revenue contribution using the Brazilian Olist e-commerce dataset.

The main objective is to understand how customers interact with the platform, identify purchasing trends, evaluate customer retention and discover which customer segments contribute the most revenue.

Using **MySQL**, I performed exploratory analysis, cohort analysis and RFM (Recency, Frequency, Monetary) segmentation to translate raw e-commerce data into meaningful business insights.

## Business Objectives

The analysis focuses on answering the following business questions:

1. How are orders distributed across different order statuses?
2. How many customers make repeat purchases compared to one-time purchases?
3. How does customer retention change over time?
4. Which customers are the most recent, frequent and valuable?
5. Which customer segments can be identified using RFM analysis?
6. Which customer segments contribute the most revenue?
7. What actions can the business take to improve customer retention?

## Tools and Technologies

- **Database:** MySQL 8.0
- **SQL Environment:** MySQL Workbench
- **Analysis Techniques:** Exploratory Data Analysis (EDA), Cohort Analysis and RFM Analysis
- **Data Source:** Brazilian Olist E-commerce Public Dataset

## Dataset

The project uses the Olist Brazilian E-commerce dataset, which contains information about customers, orders, products, sellers, payments, reviews and geolocation.

The dataset covers orders from **September 2016 to August 2018**.

The data was imported into MySQL, organised into relational tables and connected using primary and foreign keys to support structured analysis.

## Analysis Performed

### 1. Order Analysis
- Examined order status distribution.
- Identified the proportion of delivered, canceled and other orders.
- Evaluated overall order completion patterns.

### 2. Customer Purchase Behaviour
- Analysed one-time and repeat customers.
- Calculated customer purchase frequency.
- Used `customer_unique_id` to identify individual customers accurately across multiple orders.

### 3. Cohort Analysis
- Grouped customers according to their first purchase month.
- Tracked monthly purchasing activity after the first purchase.
- Calculated customer retention percentages across different cohorts.

### 4. RFM Analysis
Evaluated customers using three key metrics:

- **Recency:** Number of days since the customer's last delivered order.
- **Frequency:** Number of delivered orders placed by the customer.
- **Monetary:** Total product value purchased by the customer, excluding freight charges.

Customers were scored and classified into segments such as Champions, Loyal Customers, Potential Loyalists, Big Spenders, At Risk and Hibernating.

### 5. Revenue Analysis
- Calculated total product revenue by customer segment.
- Compared customer counts with revenue contribution.
- Identified high-value customer groups and opportunities for retention.

## Key Business Findings

| Finding | Result |
|---|---:|
| Total unique customers | 93,358 |
| Delivered orders | 96,478 |
| One-time customers | 97% |
| Repeat customers | 3% |
| Champions | 932 customers |
| Largest revenue-contributing segment | Needs Attention |
| Revenue from Needs Attention and Big Spenders | 64.21% |

### Important Insights

- Approximately 97% of customers made only one delivered purchase, indicating a significant customer retention opportunity.
- Needs Attention customers contributed **33.76%** of total product revenue.
- Big Spenders contributed **30.45%** of total product revenue, despite being one-time buyers.
- Potential Loyalists represented 15.89% of customers and offer an opportunity to encourage repeat purchases.
- Champions represented only 1% of customers, highlighting the relatively small group of highly engaged repeat buyers.

## Business Recommendations

Based on the findings, the following actions could help improve business performance:

- Introduce personalised reactivation campaigns for high-value inactive customers.
- Encourage second purchases through targeted offers and product recommendations.
- Develop loyalty rewards for Champions and repeat customers.
- Use purchase history to create personalised marketing campaigns.
- Focus on converting high-spending one-time buyers into repeat customers.

## Repository Structure

```text
Olist-Ecommerce-Customer-Analysis/
│
├── README.md
│
├── SQL/
│   └── olist_customer_analysis.sql
│
└── PowerBI/
    └── (Dashboard files will be added)
```

## How to Use This Project

1. Install MySQL 8.0 and MySQL Workbench.
2. Obtain the Olist public e-commerce dataset.
3. Import the dataset into MySQL and prepare the relational tables.
4. Open `SQL/olist_customer_analysis.sql`.
5. Execute the analysis queries section by section.
6. Review the results and business interpretations.

**Note:** The SQL analysis script assumes that the database tables have already been created and populated.

## Limitations

- The dataset represents historical transactions from 2016–2018 and does not reflect current marketplace activity.
- RFM recency is calculated relative to 30 August 2018.
- Monetary value considers product prices and excludes freight charges.
- The analysis includes delivered orders for customer purchase behaviour and RFM calculations.
- Customer segments are based on defined scoring rules and may vary with different segmentation approaches.

## Conclusion

This project demonstrates how SQL can be used to investigate customer behaviour, measure retention, identify valuable customer segments and evaluate revenue contribution.

The findings highlight that a large proportion of revenue comes from one-time buyers, creating an opportunity for the business to improve repeat purchases and strengthen customer relationships.

The analysis provides a data-driven foundation for customer retention strategies and further visualisation through a Power BI dashboard.

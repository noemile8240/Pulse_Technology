-- =====================================================
-- Pulse Technology — Sales & Customer Analytics (2019–2022)
-- File: 02_revenue_trends.sql
-- Tool: BigQuery SQL
-- Description:
--   Revenue + order volume trend analysis (monthly + quarterly),
--   including growth rates and Pre/COVID/Post comparisons.
--
-- Tables Used:
--   `Pulse-486423.pulse_tech.orders`
-- =====================================================


-- -----------------------------------------------------
-- 0) BASE ORDERS DATASET
-- -----------------------------------------------------
-- Convert purchase_ts (TIMESTAMP) → DATE for time grouping
WITH base_orders AS (
  SELECT
    order_id,
    DATE(purchase_ts) AS order_date,   -- convert timestamp to date
    usd_price AS revenue               -- rename for clarity in analysis
  FROM `pulse-486423.pulse_tech.orders`
  WHERE purchase_ts IS NOT NULL
),


-- -----------------------------------------------------
-- 1) MONTHLY REVENUE & ORDER VOLUME TREND
-- -----------------------------------------------------
monthly_trend AS (
  SELECT
    DATE_TRUNC(order_date, MONTH) AS month,
    COUNT(DISTINCT order_id) AS orders,
    SUM(revenue) AS revenue,
    SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT order_id)) AS aov
  FROM base_orders
  GROUP BY month
),


-- -----------------------------------------------------
-- 2) QUARTERLY REVENUE & ORDER VOLUME TREND
-- -----------------------------------------------------
quarterly_trend AS (
  SELECT
    DATE_TRUNC(order_date, QUARTER) AS quarter,
    COUNT(DISTINCT order_id) AS orders,
    SUM(revenue) AS revenue,
    SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT order_id)) AS aov
  FROM base_orders
  GROUP BY quarter
),


-- -----------------------------------------------------
-- 3) QUARTER-OVER-QUARTER (QoQ) GROWTH
-- -----------------------------------------------------
quarterly_growth AS (
  SELECT
    quarter,
    orders,
    revenue,
    aov,

    LAG(revenue) OVER (ORDER BY quarter) AS prev_qtr_revenue,
    SAFE_DIVIDE(
      revenue - LAG(revenue) OVER (ORDER BY quarter),
      LAG(revenue) OVER (ORDER BY quarter)
    ) AS revenue_qoq_growth_rate,

    LAG(orders) OVER (ORDER BY quarter) AS prev_qtr_orders,
    SAFE_DIVIDE(
      orders - LAG(orders) OVER (ORDER BY quarter),
      LAG(orders) OVER (ORDER BY quarter)
    ) AS orders_qoq_growth_rate
  FROM quarterly_trend
),


-- -----------------------------------------------------
-- 4) PERIOD LABELING (PRE / COVID / POST)
-- -----------------------------------------------------
orders_with_period AS (
  SELECT
    order_id,
    order_date,
    revenue,
    CASE
      WHEN order_date >= DATE '2019-01-01' AND order_date < DATE '2020-01-01'
        THEN 'Pre-COVID (2019)'
      WHEN order_date >= DATE '2020-01-01' AND order_date < DATE '2021-01-01'
        THEN 'COVID (2020)'
      WHEN order_date >= DATE '2021-01-01' AND order_date < DATE '2023-01-01'
        THEN 'Post-COVID (2021–2022)'
      ELSE 'Out of Range'
    END AS period
  FROM base_orders
),


-- -----------------------------------------------------
-- 5) PERIOD SUMMARY (REVENUE, ORDERS, AOV)
-- -----------------------------------------------------
period_summary AS (
  SELECT
    period,
    COUNT(DISTINCT order_id) AS orders,
    SUM(revenue) AS revenue,
    SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT order_id)) AS aov
  FROM orders_with_period
  WHERE period <> 'Out of Range'
  GROUP BY period
),


-- -----------------------------------------------------
-- 6) BASELINE CHECK: POST-COVID VS PRE-COVID
-- -----------------------------------------------------
baseline_comparison AS (
  SELECT
    MAX(IF(period = 'Pre-COVID (2019)', revenue, NULL)) AS pre_covid_revenue,
    MAX(IF(period = 'Post-COVID (2021–2022)', revenue, NULL)) AS post_covid_revenue,
    SAFE_DIVIDE(
      MAX(IF(period = 'Post-COVID (2021–2022)', revenue, NULL)) -
      MAX(IF(period = 'Pre-COVID (2019)', revenue, NULL)),
      MAX(IF(period = 'Pre-COVID (2019)', revenue, NULL))
    ) AS post_vs_pre_revenue_change_rate
  FROM period_summary
)

SELECT *
FROM monthly_trend
ORDER BY month;

-- =====================================================
-- Pulse Technology — Loyalty Program Analysis
-- File: 04_loyalty_analysis.sql
-- Tool: BigQuery SQL
--
-- Purpose:
--   Compare loyalty vs non-loyalty customers across:
--     • Monthly revenue trends
--     • Monthly AOV trends
--     • Repeat vs one-time behavior
--
-- Tables Used:
--   `Pulse-486423.pulse_tech.orders`
--   `Pulse-486423.pulse_tech.customers`
--
-- Key Fields:
--   orders.purchase_ts (TIMESTAMP), orders.usd_price, orders.customer_id, orders.order_id
--   customers.id, customers.loyalty_program (BOOL)
-- =====================================================


-- -----------------------------------------------------
-- 0) BASE JOIN: ORDERS + LOYALTY FLAG
-- -----------------------------------------------------
WITH base_orders AS (
  SELECT
    o.order_id,
    o.customer_id,
    DATE(o.purchase_ts) AS order_date,
    o.usd_price AS revenue,

    -- Convert BOOL loyalty_program into readable labels
    CASE
      WHEN c.loyalty_program IS TRUE THEN 'Member'
      ELSE 'Non-Member'
    END AS loyalty_status

  FROM `Pulse-486423.pulse_tech.orders` o
  LEFT JOIN `Pulse-486423.pulse_tech.customers` c
    ON o.customer_id = c.id   -- customers table uses id
  WHERE o.purchase_ts IS NOT NULL
    AND o.usd_price IS NOT NULL
),


-- -----------------------------------------------------
-- 1) MONTHLY REVENUE BY LOYALTY STATUS
-- -----------------------------------------------------
monthly_revenue AS (
  SELECT
    DATE_TRUNC(order_date, MONTH) AS month,
    loyalty_status,
    SUM(revenue) AS revenue
  FROM base_orders
  GROUP BY month, loyalty_status
),


-- -----------------------------------------------------
-- 2) MONTHLY AOV BY LOYALTY STATUS
-- -----------------------------------------------------
monthly_aov AS (
  SELECT
    DATE_TRUNC(order_date, MONTH) AS month,
    loyalty_status,
    COUNT(DISTINCT order_id) AS orders,
    SUM(revenue) AS revenue,
    SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT order_id)) AS aov
  FROM base_orders
  GROUP BY month, loyalty_status
),


-- -----------------------------------------------------
-- 3) CUSTOMER ORDER COUNTS (REPEAT VS ONE-TIME)
-- -----------------------------------------------------
customer_order_counts AS (
  SELECT
    customer_id,
    loyalty_status,
    COUNT(DISTINCT order_id) AS orders_per_customer
  FROM base_orders
  GROUP BY customer_id, loyalty_status
),


-- -----------------------------------------------------
-- 4) FLAG REPEAT VS ONE-TIME CUSTOMERS
-- -----------------------------------------------------
customer_repeat_flag AS (
  SELECT
    customer_id,
    loyalty_status,
    orders_per_customer,
    CASE
      WHEN orders_per_customer >= 2 THEN 'Repeat'
      ELSE 'One-Time'
    END AS customer_type
  FROM customer_order_counts
),


-- -----------------------------------------------------
-- 5) CUSTOMER SHARE BY TYPE WITHIN EACH LOYALTY SEGMENT
-- -----------------------------------------------------
repeat_share AS (
  SELECT
    loyalty_status,
    customer_type,
    COUNT(DISTINCT customer_id) AS customers
  FROM customer_repeat_flag
  GROUP BY loyalty_status, customer_type
),


-- -----------------------------------------------------
-- 6) PERCENT SHARE CALCULATION
-- -----------------------------------------------------
repeat_share_pct AS (
  SELECT
    loyalty_status,
    customer_type,
    customers,
    SAFE_DIVIDE(customers, SUM(customers) OVER (PARTITION BY loyalty_status)) AS customer_share
  FROM repeat_share
)

-- =====================================================
-- OUTPUT OPTIONS
-- Run ONE at a time by uncommenting.
-- =====================================================

-- A) Monthly revenue trend (Member vs Non-Member)
SELECT
  month,
  loyalty_status,
  revenue
FROM monthly_revenue
ORDER BY month, loyalty_status;


-- B) Monthly AOV trend
SELECT
   month,
   loyalty_status,
   orders,
   revenue,
   aov
FROM monthly_aov
ORDER BY month, loyalty_status;


-- C) Repeat vs One-Time customer share (stacked bar source)
SELECT
  loyalty_status,
  customer_type,
  customers,
  ROUND(100 * customer_share, 2) AS customer_share_pct
FROM repeat_share_pct
ORDER BY loyalty_status, customer_type;

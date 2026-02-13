-- =====================================================
-- Pulse Technology — Regional Performance Analysis
-- File: 05_regional_analysis.sql
-- Tool: BigQuery SQL
--
-- Purpose:
--   Analyze revenue, order volume, AOV, and contribution
--   across geographic regions.
--
-- Tables Used:
--   `Pulse-486423.pulse_tech.orders`
--   `Pulse-486423.pulse_tech.customers`
--   `Pulse-486423.pulse_tech.geo_lookup`
--
-- Key Joins:
--   orders.customer_id → customers.id
--   customers.country_code → geo_lookup.country_code
-- =====================================================


-- -----------------------------------------------------
-- 0) BASE JOIN: ORDERS + CUSTOMER + REGION
-- -----------------------------------------------------
WITH base_orders AS (
  SELECT
    o.order_id,
    DATE(o.purchase_ts) AS order_date,
    o.usd_price AS revenue,

    -- Geographic attributes
    g.country,
    g.region

  FROM `pulse-486423.pulse_tech.orders` o
  LEFT JOIN `pulse-486423.pulse_tech.customers` c
    ON o.customer_id = c.id
  LEFT JOIN `pulse-486423.pulse_tech.geo_lookup` g
    ON c.country_code = g.country

  WHERE o.purchase_ts IS NOT NULL
    AND o.usd_price IS NOT NULL
),


-- -----------------------------------------------------
-- 1) MONTHLY REVENUE BY REGION (for trend line chart)
-- -----------------------------------------------------
monthly_region_revenue AS (
  SELECT
    DATE_TRUNC(order_date, MONTH) AS month,
    region,
    SUM(revenue) AS revenue
  FROM base_orders
  GROUP BY month, region
),


-- -----------------------------------------------------
-- 2) REGIONAL PERFORMANCE SUMMARY
-- -----------------------------------------------------
regional_summary AS (
  SELECT
    region,
    COUNT(DISTINCT order_id) AS orders,
    SUM(revenue) AS revenue,
    SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT order_id)) AS aov
  FROM base_orders
  GROUP BY region
),


-- -----------------------------------------------------
-- 3) TOTAL COMPANY REVENUE (for % share)
-- -----------------------------------------------------
company_total AS (
  SELECT
    SUM(revenue) AS total_revenue
  FROM base_orders
),


-- -----------------------------------------------------
-- 4) ADD REVENUE SHARE % BY REGION
-- -----------------------------------------------------
regional_with_share AS (
  SELECT
    r.region,
    r.orders,
    r.revenue,
    r.aov,
    SAFE_DIVIDE(r.revenue, t.total_revenue) AS revenue_share
  FROM regional_summary r
  CROSS JOIN company_total t
)

-- =====================================================
-- OUTPUT OPTIONS
-- =====================================================

-- A) Monthly revenue trend by region (Tableau line chart)
SELECT
  month,
  region,
  revenue
FROM monthly_region_revenue
ORDER BY month, region;


-- B) Regional performance table (for bar charts + insights)
SELECT
   region,
   orders,
   revenue,
   aov,
   ROUND(100 * revenue_share, 2) AS revenue_share_pct
FROM regional_with_share
ORDER BY revenue DESC;


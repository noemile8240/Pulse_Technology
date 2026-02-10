-- =====================================================
-- Pulse Technology — Product Performance Analysis
-- File: 03_product_performance.sql
-- Tool: BigQuery SQL
-- Purpose:
--   Analyze product demand, value, and revenue concentration.
-- Table Used:
--  `Pulse-486423.pulse_tech.orders`
--
-- Key Metrics Produced:
--   • Orders per product
--   • Revenue per product
--   • Average Order Value (AOV)
--   • Revenue share %
-- =====================================================


-- -----------------------------------------------------
-- 1) CLEAN BASE DATA
-- -----------------------------------------------------
WITH base_orders AS (
  SELECT
    order_id,
    product_id,
    product_name,
    usd_price AS revenue
  FROM `Pulse-486423.pulse_tech.orders`
  WHERE usd_price IS NOT NULL
),


-- -----------------------------------------------------
-- 2) PRODUCT-LEVEL AGGREGATION
-- -----------------------------------------------------
product_metrics AS (
  SELECT
    product_id,
    product_name,

    COUNT(DISTINCT order_id) AS orders,
    SUM(revenue) AS total_revenue,

    -- Average order value per product
    SAFE_DIVIDE(SUM(revenue), COUNT(DISTINCT order_id)) AS aov

  FROM base_orders
  GROUP BY product_id, product_name
),


-- -----------------------------------------------------
-- 3) TOTAL REVENUE (for % contribution)
-- -----------------------------------------------------
total_company_revenue AS (
  SELECT
    SUM(total_revenue) AS company_revenue
  FROM product_metrics
),


-- -----------------------------------------------------
-- 4) ADD REVENUE SHARE % + RANK
-- -----------------------------------------------------
product_ranked AS (
  SELECT
    pm.product_id,
    pm.product_name,
    pm.orders,
    pm.total_revenue,
    pm.aov,

    -- % of total company revenue
    SAFE_DIVIDE(pm.total_revenue, t.company_revenue) AS revenue_share,

    -- Rank products by revenue (highest first)
    RANK() OVER (ORDER BY pm.total_revenue DESC) AS revenue_rank

  FROM product_metrics pm
  CROSS JOIN total_company_revenue t
)

-- A) Full product performance table 
SELECT
  product_name,
  orders,
  total_revenue,
  aov,
  ROUND(100 * revenue_share, 2) AS revenue_share_pct,
  revenue_rank
FROM product_ranked
ORDER BY total_revenue DESC;

-- B) Top 3 revenue-driving products (for concentration insight)
SELECT *
FROM product_ranked
WHERE revenue_rank <= 3
ORDER BY revenue_rank;


-- C) Revenue concentration of Top 3 vs rest of portfolio
SELECT
  CASE WHEN revenue_rank <= 3 THEN 'Top 3 Products' ELSE 'All Other Products' END AS product_group,
  SUM(total_revenue) AS revenue,
  ROUND(100 * SUM(revenue_share), 2) AS revenue_share_pct
FROM product_ranked
GROUP BY product_group
ORDER BY revenue DESC;

-- =====================================================
-- Pulse Technology — Refund & Risk Analysis
-- File: 06_refund_risk.sql
-- Tool: BigQuery SQL
--
-- Purpose:
--   Measure refund exposure by product:
--     • Refunded order count
--     • Refund rate (% of orders refunded)
--
-- Tables Used:
--   `Pulse-486423.pulse_tech.orders`
--   `Pulse-486423.pulse_tech.order_status`
--
-- Refund Logic:
--   An order is considered refunded when:
--     order_status.refund_ts IS NOT NULL
-- =====================================================


-- -----------------------------------------------------
-- 0) BASE: ORDERS + REFUND FLAG
-- -----------------------------------------------------
WITH order_refund_flag AS (
  SELECT
    o.order_id,
    o.product_name,
    o.usd_price AS revenue,

    -- Refund indicator
    CASE
      WHEN s.refund_ts IS NOT NULL THEN 1
      ELSE 0
    END AS is_refunded

  FROM `pulse-486423.pulse_tech.orders` o
  LEFT JOIN `pulse-486423.pulse_tech.order_status`s
    ON o.order_id = s.order_id

  WHERE o.usd_price IS NOT NULL
),


-- -----------------------------------------------------
-- 1) PRODUCT-LEVEL REFUND METRICS
-- -----------------------------------------------------
refund_by_product AS (
  SELECT
    product_name,

    COUNT(DISTINCT order_id) AS total_orders,
    SUM(is_refunded) AS refunded_orders,

    -- Refund rate = refunded / total
    SAFE_DIVIDE(SUM(is_refunded), COUNT(DISTINCT order_id)) AS refund_rate

  FROM order_refund_flag
  GROUP BY product_name
)

-- =====================================================
-- OUTPUT: Refund count + refund rate by product
-- =====================================================
SELECT
  product_name,
  total_orders,
  refunded_orders,
  ROUND(100 * refund_rate, 2) AS refund_rate_pct
FROM refund_by_product
ORDER BY refunded_orders DESC;

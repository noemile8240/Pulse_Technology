-- =====================================================
-- Pulse Technology Sales & Customer Analytics (2019–2022)
-- Folder: sql/data_model
-- File: 00_data_model_overview.sql
-- Tool: BigQuery SQL
-- Purpose: Validate schema, keys, and join coverage.
-- =====================================================

-- 1) Row counts
SELECT 'orders' AS table_name, COUNT(*) AS row_count
FROM `Pulse-486423.pulse_tech.orders`
UNION ALL
SELECT 'customers', COUNT(*) FROM `Pulse-486423.pulse_tech.customers`
UNION ALL
SELECT 'order_status', COUNT(*) FROM `Pulse-486423.pulse_tech.order_status`
UNION ALL
SELECT 'geo_lookup', COUNT(*) FROM `Pulse-486423.pulse_tech.geo_lookup`;

-- 2) Primary key uniqueness checks
SELECT
  'orders.order_id' AS key_name,
  COUNT(*) AS rows,
  COUNT(DISTINCT order_id) AS distinct_keys,
  COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_keys
FROM `Pulse-486423.pulse_tech.orders`
UNION ALL
SELECT
  'customers.customer_id',
  COUNT(*),
  COUNT(DISTINCT customer_id),
  COUNT(*) - COUNT(DISTINCT customer_id)
FROM `Pulse-486423.pulse_tech.customers`
UNION ALL
SELECT
  'geo_lookup.country_code',
  COUNT(*),
  COUNT(DISTINCT country_code),
  COUNT(*) - COUNT(DISTINCT country_code)
FROM `Pulse-486423.pulse_tech.geo_lookup`;

-- 3) Join coverage checks
-- 3a) Orders -> Customers: should be close to total orders
SELECT
  COUNT(*) AS joined_rows,
  (SELECT COUNT(*) FROM `Pulse-486423.pulse_tech.orders`) AS total_orders,
  (SELECT COUNT(*) FROM `Pulse-486423.pulse_tech.orders`) - COUNT(*) AS orders_missing_customer
FROM `Pulse-486423.pulse_tech.orders` o
LEFT JOIN `Pulse-486423.pulse_tech.customers` c
  ON o.customer_id = c.customer_id
WHERE c.customer_id IS NOT NULL;

-- 3b) Orders -> Order Status: identify missing statuses
SELECT
  COUNT(*) AS joined_rows,
  (SELECT COUNT(*) FROM `Pulse-486423.pulse_tech.orders`) AS total_orders,
  (SELECT COUNT(*) FROM `Pulse-486423.pulse_tech.orders`) - COUNT(*) AS orders_missing_status
FROM `Pulse-486423.pulse_tech.orders` o
LEFT JOIN `Pulse-486423.pulse_tech.order_status` s
  ON o.order_id = s.order_id
WHERE s.order_id IS NOT NULL;

-- 3c) Customers -> Geo lookup: identify missing country mappings
SELECT
  COUNT(*) AS total_customers,
  COUNT(g.country_code) AS customers_with_geo_match,
  COUNT(*) - COUNT(g.country_code) AS customers_missing_geo_match
FROM `Pulse-486423.pulse_tech.customers` c
LEFT JOIN `Pulse-486423.pulse_tech.geo_lookup` g
  ON c.country_code = g.country_code;

-- 4) Spot-check: sample rows from each table
SELECT * FROM `Pulse-486423.pulse_tech.orders` LIMIT 10;
SELECT * FROM `Pulse-486423.pulse_tech.customers` LIMIT 10;
SELECT * FROM `Pulse-486423.pulse_tech.order_status` LIMIT 10;
SELECT * FROM `Pulse-486423.pulse_tech.geo_lookup` LIMIT 10;


-- =====================================================
-- Pulse Technology Sales & Customer Analytics (2019–2022)
-- Folder: sql/data_cleaning
-- File: 01_data_cleaning.sql
-- Tool: BigQuery SQL
-- Purpose: Standardize fields + create cleaned analytical views.
-- NOTE: Views are safe (no destructive edits).

/* ============================================================
TABLE 1: ORDERS (creating table AS IS from raw CSV file
============================================================
   - Creates one row per order line from the raw dataset (distinct rows)
   - Preserves all observed values (including 0 prices or NULL currency)
   - Provides the main “fact” table for revenue/product/platform analysis
   ============================================================ */
CREATE OR REPLACE TABLE `pulse-486423.pulse_tech.orders` AS
SELECT DISTINCT
  order_id,
  CAST(user_id AS STRING) AS customer_id,
  purchase_ts,
  product_id,
  product_name,
  currency,
  SAFE_CAST(local_price AS FLOAT64) AS local_price,
  SAFE_CAST(usd_price AS FLOAT64)   AS usd_price,
  purchase_platform
FROM `pulse-486423.pulse_tech.pulse_raw`
WHERE order_id IS NOT NULL;

/* ============================================================
Sanity check for orders
   Goal:
   - Confirm table populated and core fields look reasonable
   - Quantify potential data quality issues for documentation (but do not filter)
============================================================ */
SELECT
  COUNT(*) AS orders_rows,
  COUNT(DISTINCT order_id) AS distinct_orders,
  COUNTIF(currency IS NULL OR TRIM(currency) = '') AS currency_missing,
  COUNTIF(usd_price IS NULL) AS usd_price_null,
  COUNTIF(usd_price = 0) AS usd_price_zero,
  COUNTIF(local_price IS NULL) AS local_price_null,
  COUNTIF(local_price = 0) AS local_price_zero,
  MIN(usd_price) AS min_usd_price,
  MAX(usd_price) AS max_usd_price
FROM `pulse-486423.pulse_tech.orders`;











-- -----------------------------------------------------
-- A) Clean Customers: trim text, standardize blanks to 'Unknown'
-- -----------------------------------------------------
CREATE OR REPLACE VIEW `Pulse-486423.pulse_tech.vw_customers_clean` AS
SELECT
  customer_id,
  -- standardize country code to uppercase + trim
  UPPER(TRIM(country_code)) AS country_code,

  -- normalize loyalty status
  CASE
    WHEN loyalty_status IS NULL THEN 'Non-Member'
    WHEN LOWER(TRIM(loyalty_status)) IN ('member','loyalty','yes','y') THEN 'Member'
    WHEN LOWER(TRIM(loyalty_status)) IN ('non-member','non member','no','n') THEN 'Non-Member'
    ELSE TRIM(loyalty_status)
  END AS loyalty_status,

  -- replace blanks with Unknown
  COALESCE(NULLIF(TRIM(marketing_channel), ''), 'Unknown') AS marketing_channel,

  -- keep remaining columns (add/remove as needed)
  * EXCEPT(country_code, loyalty_status, marketing_channel)
FROM `Pulse-486423.pulse_tech.customers`;

-- -----------------------------------------------------
-- B) Clean Geo Lookup: normalize country codes + region labels
-- -----------------------------------------------------
CREATE OR REPLACE VIEW `Pulse-486423.pulse_tech.vw_geo_lookup_clean` AS
SELECT
  UPPER(TRIM(country_code)) AS country_code,
  COALESCE(NULLIF(UPPER(TRIM(region)), ''), 'UNKNOWN') AS region
FROM `Pulse-486423.pulse_tech.geo_lookup`;

-- -----------------------------------------------------
-- C) Clean Orders: standardize key text + ensure date type
-- (Adjust column names below if yours differ)
-- -----------------------------------------------------
CREATE OR REPLACE VIEW `Pulse-486423.pulse_tech.vw_orders_clean` AS
SELECT
  order_id,
  customer_id,

  -- If order_date is already DATE, this is harmless.
  -- If it’s STRING/TIMESTAMP, SAFE_CAST prevents failures.
  COALESCE(
    SAFE_CAST(order_date AS DATE),
    DATE(SAFE_CAST(order_date AS TIMESTAMP))
  ) AS order_date,

  -- Standardize product name if present (optional)
  -- If you do NOT have product_name, remove these lines.
  TRIM(product_name) AS product_name,

  -- Amount sanity: keep as-is, but you can clamp negatives if needed
  total_amount,

  * EXCEPT(order_date, product_name)
FROM `Pulse-486423.pulse_tech.orders`;

-- -----------------------------------------------------
-- D) Clean Order Status: cast timestamps/dates safely
-- (Adjust column names below if yours differ)
-- -----------------------------------------------------
CREATE OR REPLACE VIEW `Pulse-486423.pulse_tech.vw_order_status_clean` AS
SELECT
  order_id,

  -- Cast any datetime-like columns safely (edit list to match your table)
  COALESCE(SAFE_CAST(ship_date AS DATE), DATE(SAFE_CAST(ship_date AS TIMESTAMP))) AS ship_date,
  COALESCE(SAFE_CAST(delivery_date AS DATE), DATE(SAFE_CAST(delivery_date AS TIMESTAMP))) AS delivery_date,
  COALESCE(SAFE_CAST(refund_date AS DATE), DATE(SAFE_CAST(refund_date AS TIMESTAMP))) AS refund_date,

  * EXCEPT(ship_date, delivery_date, refund_date)
FROM `Pulse-486423.pulse_tech.order_status`;

-- -----------------------------------------------------
-- E) Create an Enriched Analytical View (clean + joined)
-- This is what you can use for Tableau / analysis queries
-- -----------------------------------------------------
CREATE OR REPLACE VIEW `Pulse-486423.pulse_tech.vw_orders_enriched_clean` AS
SELECT
  o.order_id,
  o.order_date,
  o.total_amount,
  o.product_name,              -- remove if not in your schema
  c.customer_id,
  c.loyalty_status,
  c.marketing_channel,
  g.region,
  s.refund_date,
  s.ship_date,
  s.delivery_date
FROM `Pulse-486423.pulse_tech.vw_orders_clean` o
LEFT JOIN `Pulse-486423.pulse_tech.vw_customers_clean` c
  ON o.customer_id = c.customer_id
LEFT JOIN `Pulse-486423.pulse_tech.vw_geo_lookup_clean` g
  ON c.country_code = g.country_code
LEFT JOIN `Pulse-486423.pulse_tech.vw_order_status_clean` s
  ON o.order_id = s.order_id;

-- -----------------------------------------------------
-- F) Quick post-clean validation checks
-- -----------------------------------------------------
-- Check unknown marketing channel volume
SELECT marketing_channel, COUNT(*) AS customers
FROM `Pulse-486423.pulse_tech.vw_customers_clean`
GROUP BY marketing_channel
ORDER BY customers DESC;

-- Check region distribution
SELECT region, COUNT(*) AS customers
FROM `Pulse-486423.pulse_tech.vw_orders_enriched_clean`
GROUP BY region
ORDER BY customers DESC;

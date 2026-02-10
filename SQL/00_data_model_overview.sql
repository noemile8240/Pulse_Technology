-- =====================================================
-- Pulse Technology Sales & Customer Analytics (2019–2022)
-- Folder: sql/data_model
-- File: 00_data_model_overview.sql
-- Tool: BigQuery SQL
-- Purpose: Create schema from raw CSV file and validate data
-- =====================================================

/* ============================================================
TABLE 1: ORDERS (creating order table AS IS from raw CSV file)
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

/* ============================================================
   TABLE 2: ORDER_STATUS (creating order timeline table AS IS from raw CSV file)
============================================================
   - One row per order_id with key lifecycle dates:
       purchase_ts, ship_ts, delivery_ts, refund_ts
   - Preserves missing/NULL timestamps exactly as they appear
   - Enables fulfillment metrics (ship time, delivery time, refund timing)
   ============================================================ */

CREATE OR REPLACE TABLE `pulse-486423.pulse_tech.order_status` AS
SELECT DISTINCT
  order_id,
  purchase_ts,
  ship_ts,
  delivery_ts,
  refund_ts
FROM `pulse-486423.pulse_tech.pulse_raw`
WHERE order_id IS NOT NULL;

/* ============================================================
Sanity check: order_status ----
   Goal:
   - Quantify missingness on timeline fields
   - Identify obvious date-order anomalies for documentation
   ============================================================ */

SELECT
  COUNT(*) AS order_status_rows,
  COUNT(DISTINCT order_id) AS distinct_orders,
  COUNTIF(purchase_ts IS NULL) AS purchase_missing,
  COUNTIF(ship_ts IS NULL) AS ship_missing,
  COUNTIF(delivery_ts IS NULL) AS delivery_missing,
  COUNTIF(refund_ts IS NULL) AS refund_missing,
  COUNTIF(ship_ts IS NOT NULL AND purchase_ts IS NOT NULL AND ship_ts < purchase_ts) AS ship_before_purchase,
  COUNTIF(delivery_ts IS NOT NULL AND ship_ts IS NOT NULL AND delivery_ts < ship_ts) AS delivery_before_ship
FROM `pulse-486423.pulse_tech.order_status`;

/* ============================================================
   TABLE 3: CUSTOMERS (creating Customer Dimension table AS IS from raw CSV file)
============================================================
   - Creates one row per customer (user_id)
   - Remove duplicate multiple customer rows by taking the most recent created_on record
   - Preserves customer attributes as they appear in raw data:
     marketing_channel, account_creation_method, country_code, loyalty_program
   ============================================================ */

CREATE OR REPLACE TABLE `pulse-486423.pulse_tech.customers` AS
WITH ranked AS (
  SELECT
    CAST(user_id AS STRING) AS id,
    marketing_channel,
    account_creation_method,
    country_code,
    IF(SAFE_CAST(loyalty_program AS INT64) = 1, TRUE, FALSE) AS loyalty_program,
    created_on,
    ROW_NUMBER() OVER (
      PARTITION BY user_id
      ORDER BY created_on DESC
    ) AS rn
  FROM `pulse-486423.pulse_tech.pulse_raw`
  WHERE user_id IS NOT NULL
)
SELECT
  id,
  marketing_channel,
  account_creation_method,
  country_code,
  loyalty_program,
  created_on
FROM ranked
WHERE rn = 1;

/* ============================================================ 
Sanity check: customers ----
   Goal:
   - Confirm 1 row per customer
   - Quantify missingness in segmentation fields for documentation
 ============================================================ */

/* ============================================================
   TABLE 4: GEO_LOOKUP (creating Country Dimension table AS IS from raw CSV file)
============================================================
   - Creates a distinct list of all country_code values found in raw data
   - Keeps country codes exactly as they appear (no standardization/corrections)
   - Sets region to NULL intentionally:
     region mapping will be an enrichment/cleanup step later (optional)
   ============================================================ */
CREATE OR REPLACE TABLE `pulse-486423.pulse_tech.geo_lookup` AS
SELECT DISTINCT
  country_code AS country,
  CAST(NULL AS STRING) AS region
FROM `pulse-486423.pulse_tech.pulse_raw`
WHERE country_code IS NOT NULL;

/* ============================================================ 
Sanity check: geo_lookup ----
   Goal:
   - Confirm number of unique country codes
   - Surface blank or suspicious codes for documentation
 ============================================================ */
SELECT
  COUNT(*) AS geo_rows,
  COUNT(DISTINCT country) AS distinct_countries,
  COUNTIF(TRIM(country) = '') AS blank_country_codes
FROM `pulse-486423.pulse_tech.geo_lookup`;


/* ============================================================
   FINAL SANITY CHECKS 
   - Ensures orders can join to customers on customer_id
   - Ensures customers can join to geo_lookup on country_code
   - Any missing joins represent data quality gaps to document.
   - We keep the records as-is (no filtering) per project intent.
   ============================================================ */
SELECT
  COUNT(*) AS orders_rows,
  COUNTIF(c.id IS NULL) AS orders_missing_customer_dim
FROM `pulse-486423.pulse_tech.orders` o
LEFT JOIN `pulse-486423.pulse_tech.customers` c
  ON o.customer_id = c.id;

SELECT
  COUNT(*) AS customers_rows,
  COUNTIF(g.country IS NULL) AS customers_missing_geo_dim
FROM `pulse-486423.pulse_tech.customers` c
LEFT JOIN `pulse-486423.pulse_tech.geo_lookup` g
  ON c.country_code = g.country;
/* ============================================================
Spot-check: sample rows from each table
  ============================================================ */

SELECT * FROM `Pulse-486423.pulse_tech.orders` LIMIT 10;
SELECT * FROM `Pulse-486423.pulse_tech.customers` LIMIT 10;
SELECT * FROM `Pulse-486423.pulse_tech.order_status` LIMIT 10;
SELECT * FROM `Pulse-486423.pulse_tech.geo_lookup` LIMIT 10;


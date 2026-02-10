-- =====================================================
-- Pulse Technology Sales & Customer Analytics (2019–2022)
-- Folder: sql/data_cleaning
-- File: 01_data_cleaning.sql
-- Tool: BigQuery SQL
-- Purpose: Standardize fields + create cleaned analytical views.
-- NOTE: Views are safe (no destructive edits).
-- =====================================================
/* ============================================================
   SANITY CHECK  ON ORDERS TABLE
   ============================================================
   This query:
   - Reviews the overall health of the raw orders table.
   - Counts missing or zero values in important pricing fields.
   - Helps decide whether cleaning is actually needed.
   ============================================================ */

SELECT
  COUNT(*) AS total_rows,

  -- Currency checks
  COUNTIF(currency IS NULL OR TRIM(currency) = '') AS missing_currency,

  -- USD price checks
  COUNTIF(usd_price IS NULL) AS usd_price_null,
  COUNTIF(usd_price = 0) AS usd_price_zero,
  COUNTIF(usd_price < 0) AS usd_price_negative,

  -- Local price checks
  COUNTIF(local_price IS NULL) AS local_price_null,
  COUNTIF(local_price = 0) AS local_price_zero,
  COUNTIF(local_price < 0) AS local_price_negative

FROM `pulse-486423.pulse_tech.orders`;

/* ============================================================
   CHECKING MISSING VALUES BY COLUMN ON ORDERS TABLE
   ============================================================
This query:
   - Counts missing values for each important column in orders.
   - Uses UNION ALL to stack results into a simple readable table.
   - Helps quickly identify which fields may need cleaning.
   ============================================================ */

SELECT 'order_id' AS column_name,
       COUNTIF(order_id IS NULL) AS missing_rows
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'customer_id',
       COUNTIF(customer_id IS NULL)
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'product_id',
       COUNTIF(product_id IS NULL)
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'purchase_ts',
       COUNTIF(purchase_ts IS NULL)
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'currency',
       COUNTIF(currency IS NULL OR TRIM(currency) = '')
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'product_name',
       COUNTIF(product_name IS NULL OR TRIM(product_name) = '')
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'purchase_platform',
       COUNTIF(purchase_platform IS NULL OR TRIM(purchase_platform) = '')
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'usd_price',
       COUNTIF(usd_price IS NULL)
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'local_price',
       COUNTIF(local_price IS NULL)
FROM `pulse-486423.pulse_tech.orders`

ORDER BY missing_rows DESC;

/* ============================================================
CHECKING VALUE VALIDITY, RANGES, AND DUPLICATES ON    ORDERS TABLE
   ============================================================
   This query:
   - Stacks multiple data-quality checks into one readable result.
   - Reviews:
       • Invalid price values (negative or zero)
       • Suspicious date ranges (future dates)
       • Duplicate order identifiers
   - Uses UNION ALL so results appear in one vertical table.
   ============================================================ */
-- Negative or zero USD price
SELECT 'usd_price_negative' AS check_name,
       COUNTIF(usd_price < 0) AS issue_count
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'usd_price_zero',
       COUNTIF(usd_price = 0)
FROM `pulse-486423.pulse_tech.orders`

-- Negative or zero LOCAL price
UNION ALL
SELECT 'local_price_negative',
       COUNTIF(local_price < 0)
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'local_price_zero',
       COUNTIF(local_price = 0)
FROM `pulse-486423.pulse_tech.orders`

-- Future purchase dates
UNION ALL
SELECT 'future_purchase_dates',
       COUNTIF(purchase_ts > CURRENT_DATE())
FROM `pulse-486423.pulse_tech.orders`

-- Duplicate order IDs
UNION ALL
SELECT 'duplicate_order_ids',
       COUNT(*) - COUNT(DISTINCT order_id)
FROM `pulse-486423.pulse_tech.orders`

ORDER BY issue_count DESC;

/* ============================================================
   CHECKING PRODUCT_ID & PURCHASE_PLATFORM CONSISTENCY
   ============================================================
   This query:
   - Checks missing values for key categorical fields.
   - Counts how many distinct values exist in each column.
   - Helps detect inconsistencies, typos, or unexpected categories.
   ============================================================ */

SELECT 'product_id_missing' AS check_name,
       COUNTIF(product_id IS NULL) AS issue_count
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'purchase_platform_missing',
       COUNTIF(purchase_platform IS NULL OR TRIM(purchase_platform) = '')
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'distinct_product_ids',
       COUNT(DISTINCT product_id)
FROM `pulse-486423.pulse_tech.orders`

UNION ALL
SELECT 'distinct_product_name',
       COUNT(DISTINCT product_name)
FROM `pulse-486423.pulse_tech.orders`


UNION ALL
SELECT 'distinct_purchase_platforms',
       COUNT(DISTINCT purchase_platform)
FROM `pulse-486423.pulse_tech.orders`;

/* ============================================================
  CHECKING DUPLICATE VALUES ON PURCHASE PLATFORM & PRODUCT NAME
   ============================================================

   What this query does:
   - Identifies duplicate values in categorical fields.
   - Shows how many times each value appears.
   - Stacks results for multiple columns using UNION ALL
     so inconsistencies can be reviewed in one place.
   ============================================================ */
-- Duplicate purchase platforms
SELECT
  'purchase_platform' AS column_name,
  purchase_platform AS value,
  COUNT(*) AS occurrences
FROM `pulse-486423.pulse_tech.orders`
GROUP BY purchase_platform
HAVING COUNT(*) > 1

UNION ALL

-- Duplicate product names
SELECT
  'product_name' AS column_name,
  product_name AS value,
  COUNT(*) AS occurrences
FROM `pulse-486423.pulse_tech.orders`
GROUP BY product_name
HAVING COUNT(*) > 1
ORDER BY column_name, occurrences DESC;

/* ============================================================
After finding inconsistent spelling on one of the products (27 in 4K monitor)
This queries narrows in on the 2 different spelling entries
   ======================================================== */
SELECT
  product_name,
  COUNT(*) AS row_count
FROM `pulse-486423.pulse_tech.orders`
WHERE LOWER(product_name) LIKE '%27%'
  AND LOWER(product_name) LIKE '%4k%'
  AND LOWER(product_name) LIKE '%monitor%'
GROUP BY product_name;

/* ============================================================
AFTER FINDING ONE OF THE PRODUCTS LISTED WITH 2 SPELLING – HERE ARE THE SCRIPTS FOR FIXING IT. 
First rename original order table to order_raw_backup 
============================================================ */
ALTER TABLE `pulse-486423.pulse_tech.orders`
RENAME TO `orders_raw_backup`;

/* ============================================================
   REBUILD ORDERS TABLE WITH STANDARDIZED PRODUCT NAME
   ============================================================
     - Recreates the `orders` table from the backup.
   - Fixes the incorrect spelling of the 27in 4K gaming monitor.
   - Leaves all other rows unchanged.
   - Keeps the raw backup untouched for audit purposes.
   ============================================================ */
CREATE OR REPLACE TABLE `pulse-486423.pulse_tech.orders` AS
SELECT
  order_id,
  customer_id,
  purchase_ts,
  product_id,

  -- Standardize any 27in + 4k + monitor variation
  CASE
    WHEN REGEXP_CONTAINS(LOWER(product_name), r'27in.*4k.*monitor')
      THEN '27in 4K gaming monitor'
    ELSE product_name
  END AS product_name,

  currency,
  local_price,
  usd_price,
  purchase_platform

FROM `pulse-486423.pulse_tech.orders_raw_backup`;

/* Confirming changes worked */

SELECT
  product_name,
  COUNT(*) AS row_count
FROM `pulse-486423.pulse_tech.orders`
WHERE LOWER(product_name) LIKE '%27%'
  AND LOWER(product_name) LIKE '%4k%'
  AND LOWER(product_name) LIKE '%monitor%'
GROUP BY product_name;

--Double check

SELECT
  'product_name' AS column_name,
  product_name AS value,
  COUNT(*) AS occurrences
FROM `pulse-486423.pulse_tech.orders`
GROUP BY product_name
HAVING COUNT(*) > 1

 /* ============================================================
CHECKING FOR INCONSISTEN LABELS  
We now look at distinct values for:
•	marketing_channel
•	account_creation_method
•	country_code
============================================================ */
SELECT
  IF(TRIM(marketing_channel) = '' OR marketing_channel IS NULL, '<<BLANK>>', marketing_channel) AS marketing_channel,
  COUNT(*) AS customer_count
FROM `pulse-486423.pulse_tech.customers`
GROUP BY marketing_channel
ORDER BY customer_count DESC;
 
/* ============================================================
CHECK ACCOUNT CREATION METHOD DISTRIBUTION 
============================================================ */
SELECT
  IF(TRIM(account_creation_method) = '' OR account_creation_method IS NULL, '<<BLANK>>', account_creation_method) AS account_creation_method,
  COUNT(*) AS customer_count
FROM `pulse-486423.pulse_tech.customers`
GROUP BY account_creation_method
ORDER BY customer_count DESC;

/* ============================================================
CREATE BACKUP OF CUSTOMERS TABLE  AND  STANDARDIZE BLANK VALUES TO 'unknown'
============================================================ */
   - Recreates the customers table from the raw backup.
   - Converts blank or NULL values in:
       • marketing_channel
       • account_creation_method
     into the existing category: 'unknown'.
   - Leaves all other data unchanged.
   - Preserves the raw backup for audit and rollback.
   ============================================================ */

ALTER TABLE `pulse-486423.pulse_tech.customers`
RENAME TO `customers_raw_backup`;

CREATE OR REPLACE TABLE `pulse-486423.pulse_tech.customers` AS
SELECT
  id,

  -- Standardize blanks to 'unknown'
  CASE
    WHEN marketing_channel IS NULL OR TRIM(marketing_channel) = '' THEN 'unknown'
    ELSE marketing_channel
  END AS marketing_channel,

  CASE
    WHEN account_creation_method IS NULL OR TRIM(account_creation_method) = '' THEN 'unknown'
    ELSE account_creation_method
  END AS account_creation_method,

  country_code,
  loyalty_program,
  created_on

FROM `pulse-486423.pulse_tech.customers_raw_backup`;

/* Verify the changes worked */
SELECT
  marketing_channel,
  COUNT(*) AS customer_count
FROM `pulse-486423.pulse_tech.customers`
GROUP BY marketing_channel
ORDER BY customer_count DESC;

/* ============================================================
CHECKING  MISSING VALUES IN ORDER_STATUS TABLE
   ============================================================
   - Counts missing values in each lifecycle timestamp column.
   - Stacks results into one readable table using UNION ALL.
   - Does NOT modify any data.
   ============================================================ */
SELECT 'purchase_ts' AS column_name, COUNTIF(purchase_ts IS NULL) AS missing_rows
FROM `pulse-486423.pulse_tech.order_status`

UNION ALL
SELECT 'ship_ts', COUNTIF(ship_ts IS NULL)
FROM `pulse-486423.pulse_tech.order_status`

UNION ALL
SELECT 'delivery_ts', COUNTIF(delivery_ts IS NULL)
FROM `pulse-486423.pulse_tech.order_status`

UNION ALL
SELECT 'refund_ts', COUNTIF(refund_ts IS NULL)
FROM `pulse-486423.pulse_tech.order_status`

ORDER BY missing_rows DESC;

/* ============================================================
   SANITY CHECK — IMPOSSIBLE TIMELINES
   ============================================================
   - Detects logical date errors in the fulfillment lifecycle.
   - Only compares rows where both dates exist (NULL-safe).
   ============================================================ */
SELECT
  COUNT(*) AS total_rows,

  COUNTIF(
    purchase_ts IS NOT NULL
    AND ship_ts IS NOT NULL
    AND ship_ts < purchase_ts
  ) AS ship_before_purchase,

  COUNTIF(
    ship_ts IS NOT NULL
    AND delivery_ts IS NOT NULL
    AND delivery_ts < ship_ts
  ) AS delivery_before_ship

FROM `pulse-486423.pulse_tech.order_status`;

/* ============================================================
   CHECKING DATE RANGES
   ============================================================ */

SELECT
  MIN(purchase_ts) AS earliest_purchase,
  MAX(purchase_ts) AS latest_purchase,

  MIN(ship_ts) AS earliest_ship,
  MAX(ship_ts) AS latest_ship,

  MIN(delivery_ts) AS earliest_delivery,
  MAX(delivery_ts) AS latest_delivery,

  COUNTIF(delivery_ts > CURRENT_DATE()) AS future_deliveries
FROM `pulse-486423.pulse_tech.order_status`;

/* ============================================================
   SANITY CHECK — MISSING VALUES IN GEO_LOOKUP
   ============================================================ */

SELECT 'country' AS column_name, COUNTIF(country IS NULL OR TRIM(country) = '') AS missing_rows
FROM `pulse-486423.pulse_tech.geo_lookup`

UNION ALL
SELECT 'region', COUNTIF(region IS NULL OR TRIM(region) = '')
FROM `pulse-486423.pulse_tech.geo_lookup`

ORDER BY missing_rows DESC;

SELECT
  country,
  COUNT(*) AS row_count
FROM `pulse-486423.pulse_tech.geo_lookup`
GROUP BY country
ORDER BY row_count DESC;

-- Checking for blank regions 

SELECT
  IF(TRIM(region) = '' OR region IS NULL, '<<BLANK>>', region) AS region,
  COUNT(*) AS row_count
FROM `pulse-486423.pulse_tech.geo_lookup`
GROUP BY region
ORDER BY row_count DESC;


















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

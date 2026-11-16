\set ON_ERROR_STOP on
BEGIN;
CREATE SCHEMA IF NOT EXISTS returns_demo;
SET LOCAL search_path TO returns_demo;
DROP VIEW IF EXISTS segment_priority, monthly_cohorts, mature_lines;
DROP TABLE IF EXISTS order_lines, products;
CREATE TABLE products (
  sku text PRIMARY KEY,
  category text NOT NULL
);
CREATE TABLE order_lines (
  line_id integer PRIMARY KEY,
  sku text NOT NULL REFERENCES products,
  channel text NOT NULL CHECK (channel IN ('Direct', 'Marketplace')),
  delivered_on date NOT NULL,
  amount_rub integer NOT NULL CHECK (amount_rub > 0),
  returned_on date,
  reason text,
  CHECK ((returned_on IS NULL) = (reason IS NULL)),
  CHECK (returned_on >= delivered_on),
  CHECK (delivered_on <= DATE '2025-12-31'),
  CHECK (returned_on <= DATE '2025-12-31')
);
\copy products FROM 'data/products.csv' WITH (FORMAT csv, HEADER MATCH)
\copy order_lines FROM 'data/order_lines.csv' WITH (FORMAT csv, HEADER MATCH)

CREATE VIEW mature_lines AS
SELECT l.*, p.category, date_trunc('month', delivered_on)::date AS cohort_month,
       coalesce(returned_on <= delivered_on + 30, false) AS returned_30d
FROM order_lines l JOIN products p USING (sku)
WHERE delivered_on + 30 <= DATE '2025-12-31';

CREATE VIEW monthly_cohorts AS
SELECT cohort_month, count(*) AS delivered, count(*) FILTER (WHERE returned_30d) AS returned,
       round(100.0 * count(*) FILTER (WHERE returned_30d) / count(*), 2) AS return_pct,
       sum(amount_rub) FILTER (WHERE returned_30d) AS returned_rub
FROM mature_lines GROUP BY cohort_month;

CREATE VIEW segment_priority AS
WITH metrics AS (
  SELECT category, channel, count(*) AS delivered,
         count(*) FILTER (WHERE returned_30d) AS returned,
         coalesce(sum(amount_rub) FILTER (WHERE returned_30d), 0) AS returned_rub
  FROM mature_lines GROUP BY category, channel
)
SELECT *, round(100.0 * returned / delivered, 2) AS return_pct,
       dense_rank() OVER (ORDER BY returned_rub DESC) AS exposure_rank
FROM metrics WHERE delivered >= 100;
\ir tests.sql
COMMIT;

SELECT * FROM returns_demo.monthly_cohorts ORDER BY cohort_month;
SELECT * FROM returns_demo.segment_priority ORDER BY exposure_rank, category, channel;
SELECT reason, count(*) AS returned, sum(amount_rub) AS returned_rub
FROM returns_demo.mature_lines
WHERE returned_30d AND category = 'Apparel' AND channel = 'Marketplace'
GROUP BY reason ORDER BY returned_rub DESC, reason;

-- 03 — Concern 1b: does Magist's price level match where Eniac sells?
USE magist;

-- 3.1 Price distribution across all items
SELECT ROUND(AVG(price), 2) AS avg_price,
       ROUND(MIN(price), 2) AS min_price,
       ROUND(MAX(price), 2) AS max_price
FROM order_items;

-- 3.2 Median and upper percentiles (MySQL 8 window functions)
SELECT DISTINCT
       ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY price) OVER (), 2) AS p50,
       ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price) OVER (), 2) AS p75,
       ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY price) OVER (), 2) AS p90,
       ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY price) OVER (), 2) AS p95,
       ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY price) OVER (), 2) AS p99
FROM order_items;

-- 3.3 How rare are high-ticket items? (the Apple price class)
SELECT ROUND(100.0 * SUM(CASE WHEN price >= 500  THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_ge_500,
       ROUND(100.0 * SUM(CASE WHEN price >= 1000 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_ge_1000,
       SUM(CASE WHEN price >= 1000 THEN 1 ELSE 0 END)                               AS n_ge_1000,
       COUNT(*)                                                                     AS n_total
FROM order_items;

-- 3.4 Seller base: who can actually handle high-ticket goods?
SELECT (SELECT COUNT(DISTINCT seller_id) FROM order_items)                   AS active_sellers,
       (SELECT COUNT(DISTINCT seller_id) FROM order_items WHERE price >= 1000) AS sellers_ge_1000;

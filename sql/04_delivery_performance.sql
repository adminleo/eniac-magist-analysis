-- 04 — Concern 2: are deliveries fast enough?
USE magist;

-- 4.1 End-to-end delivery time (purchase -> delivered to customer)
SELECT COUNT(*) AS n,
       ROUND(AVG(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 1) AS avg_days,
       ROUND(MIN(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 1) AS min_days,
       ROUND(MAX(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 1) AS max_days
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL;

-- 4.2 Late rate and the buffer against the promised date
SELECT ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_late,
       ROUND(AVG(TIMESTAMPDIFF(DAY, order_delivered_customer_date, order_estimated_delivery_date)), 1) AS avg_days_early,
       ROUND(AVG(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_estimated_delivery_date)), 1)      AS avg_promised_days
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL;

-- 4.3 Quarter-on-quarter trend — is it improving?
SELECT CONCAT(DATE_FORMAT(order_purchase_timestamp, '%Y'), '-Q',
              QUARTER(order_purchase_timestamp)) AS quarter,
       COUNT(*) AS n,
       ROUND(AVG(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 1) AS avg_days,
       ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_late
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
GROUP BY quarter
HAVING n > 100
ORDER BY quarter;

-- 4.4 Regional spread (states with > 500 orders)
SELECT g.state,
       COUNT(*) AS n,
       ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)), 1) AS avg_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN geo g ON c.customer_zip_code_prefix = g.zip_code_prefix
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
GROUP BY g.state
HAVING n > 500
ORDER BY avg_days;

-- 01 — Business scope: is Magist big enough to matter?
USE magist;

-- 1.1 Platform headline figures
SELECT
    (SELECT COUNT(*) FROM orders)                  AS orders,
    (SELECT COUNT(*) FROM order_items)             AS items,
    (SELECT COUNT(*) FROM sellers)                 AS sellers,
    (SELECT COUNT(*) FROM products)                AS products,
    ROUND((SELECT SUM(price) FROM order_items), 0) AS revenue_brl;

-- 1.2 Revenue per year (delivered orders only)
SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y') AS year,
       COUNT(DISTINCT o.order_id)                    AS orders,
       ROUND(SUM(oi.price), 0)                       AS revenue_brl
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY year
ORDER BY year;

-- 1.3 Monthly order volume — the growth curve
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
       COUNT(*)                                       AS orders
FROM orders
WHERE order_status = 'delivered'
GROUP BY month
HAVING month BETWEEN '2017-01' AND '2018-08'
ORDER BY month;

-- 1.4 Order status distribution (data-quality check)
SELECT order_status, COUNT(*) AS n
FROM orders
GROUP BY order_status
ORDER BY n DESC;

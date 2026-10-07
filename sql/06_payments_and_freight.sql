-- 06 — Can the Brazilian market afford high-ticket, and what does shipping cost?
USE magist;

-- 6.1 Payment methods
SELECT payment_type, COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM order_payments), 1) AS pct
FROM order_payments
GROUP BY payment_type
ORDER BY n DESC;

-- 6.2 Instalments by basket value — does the market finance expensive purchases?
SELECT CASE WHEN v.order_value < 100  THEN '< 100'
            WHEN v.order_value < 500  THEN '100-499'
            WHEN v.order_value < 1000 THEN '500-999'
            ELSE '>= 1000' END AS basket_brl,
       COUNT(*)                               AS n,
       ROUND(AVG(p.payment_installments), 1)  AS avg_installments,
       ROUND(100.0 * SUM(CASE WHEN p.payment_installments >= 6 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_6plus
FROM (SELECT order_id, SUM(price) AS order_value FROM order_items GROUP BY order_id) v
JOIN order_payments p ON v.order_id = p.order_id
GROUP BY basket_brl
ORDER BY MIN(v.order_value);

-- 6.3 Freight share by price band — economies of scale favour expensive goods
SELECT CASE WHEN price < 50   THEN '< 50'
            WHEN price < 200  THEN '50-199'
            WHEN price < 1000 THEN '200-999'
            ELSE '>= 1000' END AS price_band,
       COUNT(*)                        AS n,
       ROUND(AVG(freight_value), 2)    AS avg_freight,
       ROUND(100.0 * SUM(freight_value) / SUM(price), 1) AS freight_pct_of_price
FROM order_items
GROUP BY price_band
ORDER BY MIN(price);

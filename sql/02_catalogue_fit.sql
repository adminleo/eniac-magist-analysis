-- 02 — Concern 1a: does Magist's catalogue fit a tech retailer?
USE magist;

-- 2.1 Top 10 categories by revenue
SELECT COALESCE(t.product_category_name_english, p.product_category_name) AS category,
       COUNT(*)                AS items,
       ROUND(SUM(oi.price), 0) AS revenue_brl,
       ROUND(AVG(oi.price), 2) AS avg_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name
GROUP BY category
ORDER BY revenue_brl DESC
LIMIT 10;

-- 2.2 Tech categories, broken out
SELECT t.product_category_name_english AS category,
       COUNT(*)                AS items,
       ROUND(SUM(oi.price), 0) AS revenue_brl,
       ROUND(AVG(oi.price), 2) AS avg_price,
       ROUND(MAX(oi.price), 2) AS max_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t
  ON p.product_category_name = t.product_category_name
WHERE t.product_category_name_english IN
      ('computers_accessories','telephony','computers','tablets_printing_image',
       'consoles_games','electronics','audio','fixed_telephony')
GROUP BY category
ORDER BY revenue_brl DESC;

-- 2.3 Tech share of items and of revenue
SELECT ROUND(100.0 * SUM(CASE WHEN t.product_category_name_english IN
         ('computers_accessories','telephony','computers','tablets_printing_image',
          'consoles_games','electronics','audio','fixed_telephony')
       THEN 1 ELSE 0 END) / COUNT(*), 1)        AS pct_items,
       ROUND(100.0 * SUM(CASE WHEN t.product_category_name_english IN
         ('computers_accessories','telephony','computers','tablets_printing_image',
          'consoles_games','electronics','audio','fixed_telephony')
       THEN oi.price ELSE 0 END) / SUM(oi.price), 1) AS pct_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name;

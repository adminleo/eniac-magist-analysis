-- 05 — What does a late delivery cost in satisfaction?
USE magist;

-- 5.1 Average review score overall
SELECT ROUND(AVG(review_score), 2) AS avg_score, COUNT(*) AS n
FROM order_reviews;

-- 5.2 Review score by punctuality — the key finding
SELECT CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'late' ELSE 'on time' END AS delivery,
       COUNT(*)                     AS n,
       ROUND(AVG(r.review_score),2) AS avg_score,
       ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_1_2_stars
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery;

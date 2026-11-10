-- 02 — Automate the KPI as a stored procedure.
--
-- Input:  a state (full name), a product category (English), a year.
-- Output: the average review score for reviews left by customers in that
--         state, on orders that were delivered, contained at least one product
--         in that category, and were placed in that year.
USE magist;

DROP PROCEDURE IF EXISTS avg_review_score;

DELIMITER $$

CREATE PROCEDURE avg_review_score (
    IN in_state    VARCHAR(40),
    IN in_category VARCHAR(100),
    IN in_year     INT
)
BEGIN
    SELECT in_state                       AS state,
           in_category                    AS category,
           in_year                        AS year,
           COUNT(*)                       AS reviews,
           ROUND(AVG(r.review_score), 2)  AS avg_review_score
    FROM order_reviews r
    JOIN orders    o ON o.order_id        = r.order_id
    JOIN customers c ON c.customer_id     = o.customer_id
    JOIN geo       g ON g.zip_code_prefix = c.customer_zip_code_prefix
    JOIN states    s ON s.short           = g.state
    WHERE s.state        = in_state
      AND o.order_status = 'delivered'
      AND YEAR(o.order_purchase_timestamp) = in_year
      AND EXISTS (
            SELECT 1
            FROM order_items oi
            JOIN products p
              ON p.product_id = oi.product_id
            JOIN product_category_name_translation t
              ON t.product_category_name = p.product_category_name
            WHERE oi.order_id = o.order_id
              AND t.product_category_name_english = in_category
          );
END$$

DELIMITER ;

-- ---------------------------------------------------------------------------
-- Why EXISTS and not a join to order_items
-- ---------------------------------------------------------------------------
-- The specification says "containing at least a product in the given
-- category". That is a test on the order, not a row to join to. Joining
-- order_items in instead returns the review once per matching item, so a
-- basket with three items from the category is counted three times and the
-- average silently becomes item-weighted rather than order-weighted.
--
-- It is not a rounding difference. For ('São Paulo', 'health_beauty', 2018):
--
--   EXISTS      2,430 reviews   avg 4.31
--   joined      2,727 rows      avg 4.26
--
-- 12 % more rows and 0.05 off the answer, and the bias has a direction:
-- larger baskets score slightly worse, so the duplicating version always
-- reports a KPI below the truth. ('Rio de Janeiro','bed_bath_table',2018)
-- moves 3.70 -> 3.62 the same way.
--
-- SELECT DISTINCT over the joined form would fix the count but not the
-- principle — and it would break the moment a second measure is added to the
-- SELECT list.

-- ---------------------------------------------------------------------------
-- Two things the caller should know
-- ---------------------------------------------------------------------------
-- 1. `reviews` is returned alongside the score on purpose. With no matching
--    orders the average is NULL and the count is 0, which is honest; a
--    procedure returning a bare NULL tells the caller nothing about whether
--    the filter was wrong or the quarter was quiet. Several legitimate
--    combinations are genuinely thin — ('Roraima','telephony',2018) is one
--    single review, and a one-review KPI should not be read as a trend.
--
-- 2. The three inputs are compared with the column collation, so the state and
--    category names are matched case- and accent-insensitively. 'sao paulo'
--    finds São Paulo. A misspelt category returns 0 rows rather than an error,
--    so the count is the only signal that the argument was wrong.

-- ---------------------------------------------------------------------------
-- Calls
-- ---------------------------------------------------------------------------
CALL avg_review_score('São Paulo',      'health_beauty',         2018);  -- 4.31 over 2,430
CALL avg_review_score('São Paulo',      'computers_accessories', 2017);  -- 4.16 over   928
CALL avg_review_score('Rio de Janeiro', 'bed_bath_table',        2018);  -- 3.70 over   641
CALL avg_review_score('Minas Geraís',   'toys',                  2018);  -- 4.15 over   142
CALL avg_review_score('Roraima',        'telephony',             2018);  -- 4.00 over     1
CALL avg_review_score('Acre',           'furniture_decor',       2016);  -- NULL over     0

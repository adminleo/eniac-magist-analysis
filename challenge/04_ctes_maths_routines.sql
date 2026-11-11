-- 04 — Breaking down complex queries, SQL maths, and stored routines.
--
-- Three of the Chapter 5 topics in one file, because they belong together: the
-- CTE makes the query readable, the arithmetic makes it answer a business
-- question, and the routine makes it callable by someone who does not write
-- SQL.
USE magist;

-- ===========================================================================
-- Part A — Subquery, CTE, temporary table
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A.1  The same question three ways
-- ---------------------------------------------------------------------------
-- Which sellers bill more than the platform average? First as a subquery in
-- WHERE. The inner query is uncorrelated — it does not mention the outer
-- query — so it runs once and is substituted as a constant.
SELECT seller_id, ROUND(SUM(price), 2) AS revenue
FROM order_items
GROUP BY seller_id
HAVING SUM(price) > (SELECT AVG(total) FROM (SELECT SUM(price) AS total
                                             FROM order_items
                                             GROUP BY seller_id) AS per_seller)
ORDER BY revenue DESC
LIMIT 10;

-- The same thing as a CTE. Identical result; the difference is that the
-- intermediate result now has a name, and a name can be referenced twice.
WITH per_seller AS (
    SELECT seller_id, SUM(price) AS revenue
    FROM order_items
    GROUP BY seller_id
),
platform AS (
    SELECT AVG(revenue) AS avg_revenue FROM per_seller
)
SELECT s.seller_id,
       ROUND(s.revenue, 2)                        AS revenue,
       ROUND(p.avg_revenue, 2)                    AS platform_avg,
       ROUND(s.revenue / p.avg_revenue, 2)        AS times_the_average
FROM per_seller s
CROSS JOIN platform p
WHERE s.revenue > p.avg_revenue
ORDER BY revenue DESC
LIMIT 10;
-- 628 of the 3,095 sellers clear the platform average of R$4,391.48 — a fifth
-- of them, which is what a long tail looks like from the inside.
--
-- That second version is the one worth writing: `per_seller` is used once but
-- `platform` is derived *from* it, and expressing that with nested subqueries
-- means writing the GROUP BY twice. Duplicated logic is duplicated bugs — fix
-- a filter in one copy and not the other and the comparison quietly stops
-- being a comparison.

-- A note on what a CTE does and does not promise. In MySQL 8 a CTE is a
-- readability construct, not a materialisation instruction: the optimiser may
-- merge it into the outer query or materialise it, and referencing it twice
-- does not guarantee it is computed once. If the intermediate result is
-- expensive and reused several times, the thing that *does* guarantee one
-- computation is a temporary table — and it can carry an index:
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_seller_rev AS
SELECT seller_id, SUM(price) AS revenue
FROM order_items
GROUP BY seller_id;

ALTER TABLE tmp_seller_rev ADD INDEX (revenue);

SELECT COUNT(*) AS sellers,
       ROUND(AVG(revenue), 2) AS avg_revenue,
       ROUND(MAX(revenue), 2) AS max_revenue
FROM tmp_seller_rev;

DROP TEMPORARY TABLE IF EXISTS tmp_seller_rev;
-- The trade: a temporary table is session-scoped and invisible to anyone else,
-- which makes it excellent for a multi-step analysis and useless as part of a
-- view or a query someone else has to run. Reach for it when a result is
-- genuinely reused several times in one session, not as a default.

-- ---------------------------------------------------------------------------
-- A.2  A recursive CTE, earning its keep
-- ---------------------------------------------------------------------------
-- A GROUP BY over a date column can only return months that have rows. If a
-- month has no orders it is not "zero" in the output — it is absent, and a
-- chart drawn from that output silently closes the gap and draws a straight
-- line through it.
--
-- A recursive CTE generates the calendar first, then LEFT JOINs the data onto
-- it, so a month with no orders arrives as an explicit 0.
WITH RECURSIVE calendar AS (
    SELECT DATE('2016-09-01') AS month_start
    UNION ALL
    SELECT month_start + INTERVAL 1 MONTH
    FROM calendar
    WHERE month_start < DATE('2018-10-01')
),
monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS ym,
           COUNT(DISTINCT o.order_id)                       AS orders,
           ROUND(SUM(oi.price), 2)                          AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY ym
)
SELECT DATE_FORMAT(c.month_start, '%Y-%m')  AS ym,
       COALESCE(m.orders, 0)                AS orders,
       COALESCE(m.revenue, 0)               AS revenue
FROM calendar c
LEFT JOIN monthly m ON m.ym = DATE_FORMAT(c.month_start, '%Y-%m')
ORDER BY ym;
-- The calendar has 26 months and the joined data has 24, so two months come
-- back as zero — and they are zero for two completely different reasons.
--
-- **2016-11** has no rows in `orders` at all. A genuine hole: not a quiet
-- month, an absent one.
--
-- **2018-10** has four orders, and all four are `canceled`. A cancelled order
-- carries no `order_items` rows, so the instant a revenue query joins
-- `order_items` the month disappears entirely — 25 months in `orders`, 24
-- after the join. The last month of the dataset is four cancellations and
-- nothing else.
--
-- That distinction is the whole argument for the date spine. Grouping by month
-- cannot express it: both months are simply missing from the output, and a
-- chart drawn from that output interpolates straight through them. The parent
-- analysis excludes the late-2018 months as "partial"; this says exactly how
-- partial, and shows that one of the two gaps has nothing to do with the
-- cut-off date.
--
-- It also explains why `orders` and `orders ⋈ order_items` disagree about how
-- long the dataset is, which is the kind of discrepancy that otherwise gets
-- noticed halfway through writing a conclusion.

-- ===========================================================================
-- Part B — SQL maths
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- B.1  Freight as a share of value, by price band
-- ---------------------------------------------------------------------------
SELECT CASE WHEN price <   50 THEN '1. under 50'
            WHEN price <  100 THEN '2. 50-100'
            WHEN price <  500 THEN '3. 100-500'
            WHEN price < 1000 THEN '4. 500-1000'
            ELSE                   '5. 1000+'  END         AS price_band,
       COUNT(*)                                            AS items,
       ROUND(AVG(price), 2)                                AS avg_price,
       ROUND(AVG(freight_value), 2)                        AS avg_freight,
       ROUND(100.0 * SUM(freight_value) / SUM(price), 1)    AS freight_pct
FROM order_items
GROUP BY price_band
ORDER BY price_band;
-- Platform-wide the ratio is 16.57 %, and the band breakdown is the reason the
-- parent analysis recommends entering with accessories rather than flagship
-- hardware — freight is a rounding error on an expensive item and a third of
-- the price on a cheap one.
--
-- Two things about the arithmetic. `100.0 *` rather than `100 *`: in MySQL
-- integer division with `/` still yields a decimal, so this one is defensive
-- rather than necessary — but the same expression in Postgres or SQLite with
-- two integers truncates to 0, and writing the literal as 100.0 makes the
-- query portable instead of accidentally correct.
--
-- And SUM(freight)/SUM(price) is not AVG(freight/price). The first weights by
-- value, the second weights every line equally, so a flood of cheap items
-- drags the second one upward. Both are defensible; they answer different
-- questions and are routinely confused.

-- ---------------------------------------------------------------------------
-- B.2  Division by zero, and what MySQL does about it
-- ---------------------------------------------------------------------------
-- 383 order lines have freight_value = 0. Inverting the ratio therefore
-- divides by zero on those rows.
SELECT COUNT(*)                                   AS zero_freight_rows,
       MAX(price / NULLIF(freight_value, 0))      AS max_ratio_guarded
FROM order_items
WHERE freight_value = 0;
-- In MySQL, `x / 0` returns NULL rather than raising — unless the session runs
-- with ERROR_FOR_DIVISION_BY_ZERO, in which case the same statement errors.
-- Either way the behaviour depends on a session variable, so the arithmetic is
-- not portable and not self-documenting.
--
-- NULLIF(denominator, 0) makes the intent explicit and the result the same
-- everywhere: the row yields NULL because the ratio is undefined, which is a
-- statement about the data rather than about a server setting. Aggregates then
-- skip it, as they skip any NULL.
SELECT ROUND(AVG(price / NULLIF(freight_value, 0)), 2) AS avg_price_per_freight_unit
FROM order_items;

-- ===========================================================================
-- Part C — Stored routines
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- C.1  A function: freight as a percentage, guarded
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS freight_pct;

DELIMITER $$

CREATE FUNCTION freight_pct (in_price DECIMAL(10,2), in_freight DECIMAL(10,2))
RETURNS DECIMAL(6,2)
DETERMINISTIC
NO SQL
BEGIN
    IF in_price IS NULL OR in_price = 0 THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(100 * in_freight / in_price, 2);
END$$

DELIMITER ;

SELECT order_id, price, freight_value, freight_pct(price, freight_value) AS pct
FROM order_items
ORDER BY pct DESC
LIMIT 5;
-- The two characteristics are not decoration. Without `DETERMINISTIC` the
-- optimiser must assume the function may return something different for the
-- same arguments, so it cannot cache or reorder around it. `NO SQL` says the
-- body touches no tables, which is what makes it safe to evaluate per row.
--
-- The one that bites in production: on a server with binary logging enabled,
-- CREATE FUNCTION is refused outright unless the creator holds SUPER or
-- log_bin_trust_function_creators is on — because a non-deterministic function
-- would replicate differently on the replica than on the primary. The error
-- names neither cause, so it is worth recognising on sight.

-- ---------------------------------------------------------------------------
-- C.2  A procedure with an OUT parameter
-- ---------------------------------------------------------------------------
-- 02_kpi_procedure.sql returns a result set, which is right for a dashboard.
-- A caller that wants one number to compute with wants it in a variable
-- instead, and that is what OUT is for.
DROP PROCEDURE IF EXISTS state_delivery_days;

DELIMITER $$

CREATE PROCEDURE state_delivery_days (
    IN  in_state      VARCHAR(40),
    OUT out_avg_days  DECIMAL(6,2),
    OUT out_orders    INT
)
BEGIN
    SELECT ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                                        o.order_delivered_customer_date)), 2),
           COUNT(*)
      INTO out_avg_days, out_orders
    FROM orders    o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN geo       g ON g.zip_code_prefix = c.customer_zip_code_prefix
    JOIN states    s ON s.short = g.state
    WHERE s.state = in_state
      AND o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL;
END$$

DELIMITER ;

CALL state_delivery_days('Pará', @days, @n);
SELECT @days AS avg_days, @n AS orders;      -- 23.32 days over 946 orders

CALL state_delivery_days('São Paulo', @days, @n);
SELECT @days AS avg_days, @n AS orders;      -- 8.30 days over 40,493 orders
-- Pará waits 23.32 days against São Paulo's 8.30 — 2.8 times as long. The INTO form is the
-- reason to use OUT at all: the values land in session variables, so the next
-- statement can divide one by the other instead of a human reading two result
-- sets and doing it by hand.
--
-- One hazard worth stating: SELECT ... INTO requires the query to return
-- exactly one row. This one aggregates, so it always does — even for a state
-- with no delivered orders, where it returns a single row of NULLs. Drop the
-- aggregate and pass a state matching two rows, and the procedure raises
-- instead of picking one.

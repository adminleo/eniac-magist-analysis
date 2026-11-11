-- 03 — Window functions on the Magist database.
--
-- MySQL got window functions in 8.0 (2018), which is why interviewers still use
-- them as a proxy for "has this person kept up". The point of a window function
-- is that it aggregates *without collapsing rows*: every input row survives and
-- gains a column computed over its window frame.
--
-- Two of the exercises below produce findings the parent analysis missed, and
-- two demonstrate traps that return a plausible-looking wrong answer.
USE magist;

-- ---------------------------------------------------------------------------
-- 3.1  PARTITION BY — a value and its group's average, side by side
-- ---------------------------------------------------------------------------
-- The thing GROUP BY cannot do: keep the individual price *and* show what its
-- category averages, in one row.
WITH p AS (
    SELECT t.product_category_name_english AS category, oi.price
    FROM order_items oi
    JOIN products pr ON pr.product_id = oi.product_id
    JOIN product_category_name_translation t
      ON t.product_category_name = pr.product_category_name
)
SELECT category,
       price,
       ROUND(AVG(price) OVER (PARTITION BY category), 2)         AS category_avg,
       ROUND(price - AVG(price) OVER (PARTITION BY category), 2) AS above_avg
FROM p
WHERE category = 'computers'
ORDER BY price DESC
LIMIT 10;
-- The top `computers` item is R$6,729 against a category average of R$1,098 —
-- it sits R$5,631 above its own category. Collapse the rows with GROUP BY and
-- that comparison is gone.

-- ---------------------------------------------------------------------------
-- 3.2  ROW_NUMBER vs RANK vs DENSE_RANK — not interchangeable
-- ---------------------------------------------------------------------------
-- 195 revenue values in this table are shared by more than one seller, so the
-- three functions genuinely disagree. Ties are not hypothetical here.
WITH s AS (
    SELECT seller_id, ROUND(SUM(price), 2) AS revenue
    FROM order_items
    GROUP BY seller_id
),
ranked AS (
    SELECT seller_id, revenue,
           ROW_NUMBER() OVER (ORDER BY revenue DESC) AS row_num,
           RANK()       OVER (ORDER BY revenue DESC) AS rnk,
           DENSE_RANK() OVER (ORDER BY revenue DESC) AS dense_rnk
    FROM s
)
SELECT * FROM ranked
WHERE revenue IN (SELECT revenue FROM s GROUP BY revenue HAVING COUNT(*) > 1)
ORDER BY revenue DESC, row_num
LIMIT 10;
-- Two sellers both on R$9,731.85 get row_num 301 and 302, but rnk 301 and 301.
--
-- Over all 3,095 sellers: max row_num 3,095, max rnk 3,095, max dense_rnk
-- 2,766. RANK skips 329 positions to keep the row count honest; DENSE_RANK
-- refuses to skip and so stops 329 short of the row count.
--
-- Which matters when the question is "the top 10 sellers". ROW_NUMBER returns
-- exactly ten rows but breaks the tie *arbitrarily* — the losing seller is
-- whichever one the optimiser happened to read second, and the answer can
-- change between runs with no change to the data. RANK returns everyone tied
-- at the boundary, so it may return eleven rows. Both are defensible; silently
-- picking ROW_NUMBER for a leaderboard is not.

-- ---------------------------------------------------------------------------
-- 3.3  LAG — month-over-month growth, and why the first months are useless
-- ---------------------------------------------------------------------------
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS ym,
           ROUND(SUM(oi.price), 2)                          AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY ym
)
SELECT ym,
       revenue,
       LAG(revenue) OVER (ORDER BY ym)                                  AS prev_month,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY ym))
             / LAG(revenue) OVER (ORDER BY ym), 1)                      AS pct_change
FROM monthly
ORDER BY ym;
-- The first row has a NULL prev_month — LAG has nothing to look back at, and
-- NULL is the correct answer rather than zero.
--
-- The next three rows are worse than useless. December 2016 contains a single
-- order worth R$10.90, so the series reads -100.0 % into it and +1,025,573.0 %
-- out of it. Neither number means anything: percentage change against a
-- near-zero base is undefined in practice even though SQL computes it happily.
-- The parent analysis drops the partial months for exactly this reason, and
-- this query is where the reason becomes visible. From 2017-02 onward the
-- figures are real (2018-06 at -12.4 %, 2018-08 at -3.4 %).

-- ---------------------------------------------------------------------------
-- 3.4  The default frame — LAST_VALUE's trap
-- ---------------------------------------------------------------------------
-- An ORDER BY inside OVER() brings a default frame with it:
-- RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW. So the "last value" is
-- the last value *so far*, which for every row is its own.
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS ym,
           ROUND(SUM(oi.price), 2)                          AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY ym
)
SELECT ym,
       revenue,
       LAST_VALUE(revenue) OVER (ORDER BY ym)                AS looks_right,
       LAST_VALUE(revenue) OVER (ORDER BY ym
             ROWS BETWEEN UNBOUNDED PRECEDING
                      AND UNBOUNDED FOLLOWING)              AS actually_last,
       FIRST_VALUE(revenue) OVER (ORDER BY ym)               AS first_month
FROM monthly
ORDER BY ym;
-- `looks_right` is a perfect copy of `revenue`: 134.97, 40325.11, 10.90, …
-- `actually_last` is 838576.64 on every row, which is what was asked for.
--
-- This is the trap worth remembering, because it does not error and it does not
-- look broken — it looks like a column of data. FIRST_VALUE is unaffected,
-- since the frame already starts at UNBOUNDED PRECEDING, which is precisely
-- why the bug is easy to miss: the pair appears to work and only one of them
-- does.

-- ---------------------------------------------------------------------------
-- 3.5  Top-N per group, and each seller's share of its state
-- ---------------------------------------------------------------------------
-- The canonical interview answer: rank inside a CTE, filter outside it. The
-- rank cannot go in a WHERE clause of the same SELECT, because window
-- functions are evaluated after WHERE.
WITH seller_rev AS (
    SELECT st.state, oi.seller_id, ROUND(SUM(oi.price), 2) AS revenue
    FROM order_items oi
    JOIN sellers s  ON s.seller_id = oi.seller_id
    JOIN geo     g  ON g.zip_code_prefix = s.seller_zip_code_prefix
    JOIN states  st ON st.short = g.state
    GROUP BY st.state, oi.seller_id
),
ranked AS (
    SELECT state, seller_id, revenue,
           ROW_NUMBER() OVER (PARTITION BY state ORDER BY revenue DESC)        AS n,
           ROUND(100.0 * revenue / SUM(revenue) OVER (PARTITION BY state), 1)  AS pct_of_state
    FROM seller_rev
)
SELECT state, n, seller_id, revenue, pct_of_state
FROM ranked
WHERE n <= 3
ORDER BY state, n;
-- Note the two different windows in one SELECT: ROW_NUMBER partitions by state
-- to rank, SUM partitions by state to total. Same partition, different job.
--
-- The join to `states` is not only cosmetic. Seven of the 3,095 sellers have a
-- zip prefix that geocodes to a NULL state, and without the inner join they
-- form their own partition: a nameless "state" whose top seller is 53.5 % of
-- it. PARTITION BY groups NULLs together rather than discarding them, so a
-- window function will happily rank the unknowns against each other and
-- present the result as a region. Four customers have the same problem on the
-- other side of the schema.

-- ---------------------------------------------------------------------------
-- 3.6  Supplier concentration — a finding, not an exercise
-- ---------------------------------------------------------------------------
WITH seller_rev AS (
    SELECT st.state, oi.seller_id, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN sellers s  ON s.seller_id = oi.seller_id
    JOIN geo     g  ON g.zip_code_prefix = s.seller_zip_code_prefix
    JOIN states  st ON st.short = g.state
    GROUP BY st.state, oi.seller_id
),
ranked AS (
    SELECT state, revenue,
           ROW_NUMBER() OVER (PARTITION BY state ORDER BY revenue DESC) AS n,
           SUM(revenue) OVER (PARTITION BY state)                       AS state_total,
           COUNT(*)     OVER (PARTITION BY state)                       AS sellers_in_state
    FROM seller_rev
)
SELECT state,
       sellers_in_state,
       ROUND(100.0 * SUM(CASE WHEN n <= 3 THEN revenue END) / MAX(state_total), 1) AS top3_pct
FROM ranked
GROUP BY state, sellers_in_state
HAVING sellers_in_state >= 10
ORDER BY top3_pct DESC;
-- Bahia: 20 sellers, and three of them are 89.0 % of the state's revenue.
-- Ceará 84.0 % of 13. Espírito Santo 75.8 % of 24. São Paulo, by contrast,
-- spreads its revenue so thinly that the top three together are about 7 %.
--
-- This is a concentration risk the parent analysis does not mention, and it
-- strengthens its recommendation rather than weakening it: outside São Paulo
-- and the Southeast, "Magist has 3,095 sellers" is not the number that matters
-- — the number that matters is that in most states a handful of sellers *are*
-- the supply, and losing one of them is a regional outage.

-- ---------------------------------------------------------------------------
-- 3.7  NTILE — delivery quartiles per state
-- ---------------------------------------------------------------------------
-- MySQL has no PERCENTILE_CONT, so NTILE(4) plus the max of each tile is the
-- usual way to approximate quartile boundaries.
WITH d AS (
    SELECT st.state,
           TIMESTAMPDIFF(DAY, o.order_purchase_timestamp,
                              o.order_delivered_customer_date) AS days
    FROM orders    o
    JOIN customers c  ON c.customer_id = o.customer_id
    JOIN geo       g  ON g.zip_code_prefix = c.customer_zip_code_prefix
    JOIN states    st ON st.short = g.state
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
tiles AS (
    SELECT state, days, NTILE(4) OVER (PARTITION BY state ORDER BY days) AS q
    FROM d
)
SELECT state,
       COUNT(*)                            AS deliveries,
       MAX(CASE WHEN q = 1 THEN days END)  AS p25,
       MAX(CASE WHEN q = 2 THEN days END)  AS median,
       MAX(CASE WHEN q = 3 THEN days END)  AS p75
FROM tiles
GROUP BY state
HAVING deliveries >= 500
ORDER BY median DESC;
-- Pará: 15 / 21 / 28 days. Maranhão 14 / 19 / 25. Against a platform-wide mean
-- of 12.1 days, a quarter of Pará's customers wait 28 days or more.
--
-- The mean hides this and the median does not, which is the argument for
-- quartiles over an average whenever the distribution has a tail — and a
-- delivery-time distribution always has a tail.

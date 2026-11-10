-- 01 — Analyse customer reviews by state.
--
-- Four questions against the full 98,371-review table. Every number quoted in
-- the comments is what these statements actually return.
USE magist;

-- ---------------------------------------------------------------------------
-- 1.1  Average review score by state of the customer.
-- ---------------------------------------------------------------------------
-- The chain is reviews -> orders -> customers -> geo -> states. Nothing is
-- lost to it except four reviews whose zip prefix geocodes to a NULL state:
-- 98,367 of 98,371 survive.
SELECT s.state,
       COUNT(*)                      AS reviews,
       ROUND(AVG(r.review_score), 2) AS avg_score
FROM order_reviews r
JOIN orders    o ON o.order_id         = r.order_id
JOIN customers c ON c.customer_id      = o.customer_id
JOIN geo       g ON g.zip_code_prefix  = c.customer_zip_code_prefix
JOIN states    s ON s.short            = g.state
GROUP BY s.state
ORDER BY avg_score DESC;
-- Paraná 4.18 at the top, Roraima 3.61 at the bottom — a spread of 0.57 stars.
-- The ordering tracks the North/Northeast split that runs through the whole
-- Magist dataset: the states that wait longest for a parcel rate it worst.

-- ---------------------------------------------------------------------------
-- 1.2  Do reviews containing positive words score better?
-- ---------------------------------------------------------------------------
-- Two choices have to be made before this can be written, and both change the
-- answer.
--
-- First, which text. A review has a title and a message; a review titled
-- "Ótimo" with an empty body plainly contains a positive word, so both columns
-- are searched. Message-only would find 13,138 reviews instead of 16,421.
--
-- Second, LIKE and not REGEXP. The table collation is utf8mb4_0900_ai_ci —
-- accent-insensitive — and LIKE applies it, so '%otimo%' also matches "ótimo",
-- which is how the word is actually spelled. That is not a nicety: 'otimo'
-- matches 981 reviews under an accent-sensitive comparison and 3,429 under
-- this one. Three quarters of the hits for that word are carried by the
-- collation, not by the pattern. Port the query to SQLite or Postgres and they
-- vanish without an error. (REGEXP would also avoid the substring problem
-- below, but its accent handling is not the column collation's, so LIKE is the
-- construct whose behaviour here is pinned down.)
--
-- Substring matching does let 'bom' match inside longer words. Measured, that
-- costs 12 reviews out of 5,526 — 0.2 %, almost all "bomba" — so the simple
-- pattern stands.
SELECT CASE WHEN f.positive THEN 'contains a positive word' ELSE 'does not' END AS bucket,
       COUNT(*)                        AS reviews,
       ROUND(AVG(f.review_score), 3)   AS avg_score
FROM (
    SELECT r.review_score,
           CONCAT(COALESCE(r.review_comment_message,''), ' ',
                  COALESCE(r.review_comment_title,''))        AS txt,
           (CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%bom%'
         OR CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%otimo%'
         OR CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%gostei%'
         OR CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%recomendo%'
         OR CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%excelente%') AS positive
    FROM order_reviews r
) f
GROUP BY bucket
ORDER BY avg_score DESC;
-- Yes: 4.485 across 16,421 reviews, against 3.994 for the other 81,950.

-- But "does not" lumps together two populations that behave nothing alike.
-- Split it:
SELECT CASE WHEN TRIM(f.txt) = '' THEN 'left no text at all'
            WHEN f.positive     THEN 'text, positive word'
            ELSE                     'text, no positive word' END AS bucket,
       COUNT(*)                      AS reviews,
       ROUND(AVG(f.review_score), 3) AS avg_score
FROM (
    SELECT r.review_score,
           CONCAT(COALESCE(r.review_comment_message,''), ' ',
                  COALESCE(r.review_comment_title,''))        AS txt,
           (CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%bom%'
         OR CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%otimo%'
         OR CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%gostei%'
         OR CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%recomendo%'
         OR CONCAT(COALESCE(r.review_comment_message,''), ' ',
                   COALESCE(r.review_comment_title,'')) LIKE '%excelente%') AS positive
    FROM order_reviews r
) f
GROUP BY bucket
ORDER BY avg_score DESC;
--   text, positive word      16,421   4.485
--   left no text at all      55,556   4.378
--   text, no positive word   26,394   3.183
--
-- Silence is the second most positive signal in the dataset. 56 % of reviewers
-- write nothing and average 4.38; people reach for the keyboard when something
-- went wrong. So the honest contrast is between the two groups who did write —
-- 4.485 against 3.183, a gap of 1.30 stars, not the 0.49 the two-bucket
-- version reports. Keyword sentiment on this table is really measuring who
-- bothered to type, and only then what they typed.

-- ---------------------------------------------------------------------------
-- 1.3  Among states with at least 30 positive-word reviews, highest score?
-- ---------------------------------------------------------------------------
SELECT s.state,
       COUNT(*)                      AS positive_reviews,
       ROUND(AVG(r.review_score), 3) AS avg_score
FROM order_reviews r
JOIN orders    o ON o.order_id        = r.order_id
JOIN customers c ON c.customer_id     = o.customer_id
JOIN geo       g ON g.zip_code_prefix = c.customer_zip_code_prefix
JOIN states    s ON s.short           = g.state
WHERE CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%bom%'
   OR CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%otimo%'
   OR CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%gostei%'
   OR CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%recomendo%'
   OR CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%excelente%'
GROUP BY s.state
HAVING COUNT(*) >= 30
ORDER BY avg_score DESC;
-- Rio Grande do Norte, 4.644 over 87 reviews.
--
-- Read that answer with care. Tocantins is at 4.642 over 53 — two thousandths
-- behind — and Mato Grosso at 4.609 over 179. The 95 % interval on Rio Grande
-- do Norte alone is ±0.14, so all three overlap comfortably. The query has one
-- top row; the data has a three-way tie, and a rerun on next month's reviews
-- would reorder it.
--
-- The HAVING is doing real work: it removes Acre, Amapá, Amazonas and Roraima,
-- which have 18, 11, 27 and 7 positive reviews respectively.

-- ---------------------------------------------------------------------------
-- 1.4  Where is the gap between all reviews and positive-word reviews largest?
-- ---------------------------------------------------------------------------
-- Both averages come out of one pass. AVG over a CASE with no ELSE skips the
-- NULLs it produces, so the second average covers the positive subset only
-- while COUNT(*) still counts every review of the state.
SELECT s.state,
       COUNT(*)                                        AS all_reviews,
       ROUND(AVG(f.review_score), 3)                   AS all_avg,
       SUM(f.positive)                                 AS positive_reviews,
       ROUND(AVG(CASE WHEN f.positive THEN f.review_score END), 3) AS positive_avg,
       ROUND(AVG(CASE WHEN f.positive THEN f.review_score END)
             - AVG(f.review_score), 3)                 AS lift
FROM (
    SELECT r.review_score, o.customer_id,
           (CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%bom%'
         OR CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%otimo%'
         OR CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%gostei%'
         OR CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%recomendo%'
         OR CONCAT(COALESCE(r.review_comment_message,''),' ',COALESCE(r.review_comment_title,'')) LIKE '%excelente%') AS positive
    FROM order_reviews r
    JOIN orders o ON o.order_id = r.order_id
) f
JOIN customers c ON c.customer_id     = f.customer_id
JOIN geo       g ON g.zip_code_prefix = c.customer_zip_code_prefix
JOIN states    s ON s.short           = g.state
GROUP BY s.state
HAVING positive_reviews >= 30
ORDER BY lift DESC;
-- Sergipe, +0.793 (3.785 overall -> 4.577 over 71 positive reviews).
--
-- Without the HAVING the top row is Roraima at +1.106, computed from seven
-- reviews. That is what the question asks for literally and it is worth
-- nothing; the same 30-review floor question 1.3 imposes belongs here too.
-- Drop the HAVING line to see it.
--
-- The pattern underneath the ranking: largest lift goes with worst baseline.
-- Sergipe, Pará, Rio de Janeiro, Ceará and Maranhão all sit below 3.9 overall
-- and all gain more than half a star. Where service is reliable the satisfied
-- customers already are the average, so there is nothing to lift — Acre gains
-- 0.010. The lift is not measuring enthusiasm. It measures how far a state's
-- happy customers sit above their own neighbours.

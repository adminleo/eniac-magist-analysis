# SQL interview prep — on the Magist database

The Chapter 5 material, worked against the same Magist database as the analysis
in the parent directory, extended with a `states` lookup table so results can
be reported by full state name: the final challenge (reviews by state, and a
KPI as a stored procedure), plus window functions, CTEs, SQL arithmetic and
stored routines.

Every number below was produced by the statements in this directory. To
re-derive them:

```bash
python3 tools/verify_challenge.py
```

| File | What it holds |
|---|---|
| `00_states_table.sql` | the provided DDL, plus the check that makes the foreign key safe |
| `01_reviews_by_state.sql` | the four review questions |
| `02_kpi_procedure.sql` | `avg_review_score(state, category, year)` |
| `03_window_functions.sql` | `PARTITION BY`, rank family, `LAG`, frames, top-N per group, `NTILE` |
| `04_ctes_maths_routines.sql` | subquery vs CTE vs temp table, recursive date spine, arithmetic traps, a stored `FUNCTION` and an `OUT` procedure |

## The answers

**Average review score by state.** Paraná leads at 4.18, Roraima trails at
3.61 — a 0.57-star spread that lines up with the North/Northeast delivery
split visible everywhere else in this dataset.

**Do positive words mean better scores?** Yes. 4.485 across 16,421 reviews
against 3.994 for the other 81,950.

**Highest score among states with ≥30 positive reviews.** Rio Grande do Norte,
4.644 over 87 reviews — with Tocantins two thousandths behind at 4.642 and
Mato Grosso at 4.609.

**Largest gap between all reviews and positive reviews.** Sergipe, +0.793
(3.785 → 4.577). Without a minimum-sample floor the top row is Roraima at
+1.106, computed from seven reviews.

## Two things worth more than the answers

**Most of "ótimo" lives in the collation, not the query.** The table is
`utf8mb4_0900_ai_ci`, and LIKE applies that collation, so `'%otimo%'` matches
the accented spelling. Under an accent-sensitive comparison the same pattern
finds 981 reviews; under this one, 3,429. Three quarters of the hits for that
word depend on a property of the column, not of the pattern — and moving the
query to SQLite or Postgres drops them with no error and no warning. The
verifier in `tools/` has to replace SQLite's LIKE operator outright to
reproduce the MySQL numbers.

**Silence is the second most positive signal in the data.** Splitting reviews
three ways instead of two:

| | reviews | avg score |
|---|---:|---:|
| text, positive word | 16,421 | 4.485 |
| no text at all | 55,556 | 4.378 |
| text, no positive word | 26,394 | 3.183 |

56 % of reviewers write nothing and average 4.38. People reach for the
keyboard when something went wrong. So the two-bucket comparison — positive
text against everything else — dilutes the signal with 55,556 contented silent
five-stars and reports a 0.49 gap; between the two groups who actually wrote
something the gap is **1.30 stars**. A keyword rule on this table is mostly
sorting people by whether they typed, and only then by what they typed.

That also explains question four. The states with the biggest lift are the
states with the worst baseline — Sergipe, Pará, Rio de Janeiro, Ceará and
Maranhão all sit below 3.9 overall and all gain more than half a star, while
Acre gains 0.010. The lift is not measuring enthusiasm; it measures how far a
state's satisfied customers sit above their own neighbours.

## On the procedure

`avg_review_score` tests the category with `EXISTS` rather than joining
`order_items`. The specification says the order must *contain* a product in
the category — a predicate on the order, not a row to join to. Joining returns
the review once per matching item, which makes the average item-weighted:

| ('São Paulo', 'health_beauty', 2018) | rows | avg |
|---|---:|---:|
| `EXISTS` | 2,430 | 4.31 |
| joined to `order_items` | 2,727 | 4.26 |

12 % more rows and 0.05 off the answer, biased one way — larger baskets score
slightly worse, so the duplicating version always under-reports.

The procedure returns the review count next to the score. With no matching
orders the average is NULL and the count is 0, which is a real answer;
`('Roraima','telephony',2018)` returns one single review, and a KPI built on
one review should not be read as a trend by whatever dashboard calls this.


---

# Window functions, CTEs and routines

## Two findings the parent analysis does not have

**Supply outside São Paulo is three sellers deep.** Ranking sellers within
their state and taking each one's share of state revenue:

| state | sellers | top 3 = % of state revenue |
|---|---:|---:|
| Bahía | 20 | **89.0 %** |
| Ceará | 13 | **84.0 %** |
| Espirito Santo | 24 | **75.8 %** |
| Rio de Janeiro | 176 | 37.6 % |
| São Paulo | 1,849 | ~7 % |

"Magist has 3,095 sellers" is the wrong number to reassure anyone with. In most
states a handful of sellers *are* the supply, and losing one is a regional
outage. It argues for the parent recommendation — enter through São Paulo and
the Southeast — on a ground the parent analysis never raised.

**The dataset has two month-shaped holes, for two different reasons.** A
recursive CTE generates the 26-month calendar and the data is LEFT JOINed onto
it, so a month with no orders arrives as an explicit zero instead of being
absent:

- **2016-11** has no rows in `orders` at all.
- **2018-10** has four orders, all `canceled`. Cancellations carry no
  `order_items` rows, so the month vanishes the moment a revenue query joins
  line items — 25 months in `orders`, 24 after the join.

`GROUP BY` cannot express that difference; both months are simply missing from
its output, and a chart interpolates straight through them. It also explains why
`orders` and `orders ⋈ order_items` disagree about how long the dataset is.

## Three traps that return a plausible wrong answer

**`LAST_VALUE` with the default frame returns the current row.** An `ORDER BY`
inside `OVER()` brings `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` with
it, so the "last value" is the last one *so far*:

| ym | revenue | `LAST_VALUE(revenue) OVER (ORDER BY ym)` | …with the full frame |
|---|---:|---:|---:|
| 2016-09 | 134.97 | 134.97 | 838,576.64 |
| 2016-10 | 40,325.11 | 40,325.11 | 838,576.64 |
| 2016-12 | 10.90 | 10.90 | 838,576.64 |

The third column is a copy of the second. It does not error and it does not look
broken — it looks like data. `FIRST_VALUE` is unaffected, which is what makes it
easy to miss: the pair appears to work and only one of them does.

**`ROW_NUMBER` breaks ties arbitrarily.** 195 revenue values in this table are
shared by more than one seller. Over 3,095 sellers, the maximum `ROW_NUMBER` is
3,095, the maximum `RANK` 3,095, the maximum `DENSE_RANK` 2,766 — `RANK` skips
329 positions to keep the row count honest, `DENSE_RANK` refuses to skip and
stops 329 short. For "the top 10 sellers", `ROW_NUMBER` returns exactly ten rows
and the excluded seller is whichever one the optimiser read second; the answer
can change between runs with no change to the data.

**`PARTITION BY` treats NULL as a group.** Seven of the 3,095 sellers have a zip
prefix that geocodes to a NULL state. Without an inner join to `states` they
form their own partition — a nameless region whose top seller holds 53.5 % of
it — and a window function ranks the unknowns against each other and presents
the result as a place.

## On percentage change

`LAG` makes month-over-month growth a one-liner, and the first rows of this
series are: 2016-12 at **−100.0 %**, then 2017-01 at **+1,025,573.0 %**. The
base is a single order worth R$10.90. SQL computes it happily; it means nothing.
This is why the parent analysis drops the partial months, and this query is
where the reason becomes visible rather than asserted.

## On the arithmetic

Freight is **47.1 %** of value on items under R$50 and **3.8 %** above R$1,000 —
on a cheap item the shipping is half the product. Two notes that matter more
than the figures: `SUM(freight)/SUM(price)` is not `AVG(freight/price)` (the
first weights by value, the second weights every line equally, and they are
routinely confused), and `NULLIF(denominator, 0)` is how a division stays
portable — in MySQL `x/0` yields NULL or raises depending on whether the session
has `ERROR_FOR_DIVISION_BY_ZERO` set, so unguarded division is a statement about
a server setting rather than about the data. 383 order lines have zero freight.

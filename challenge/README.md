# Final SQL challenge — reviews by state, and a KPI as a procedure

Two questions adapted from a real technical interview, run against the same
Magist database as the analysis in the parent directory, extended with a
`states` lookup table so results can be reported by full state name.

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

# Team guide — what's in here and how to use it

This repo holds the analysis behind our Magist recommendation: the queries, the
numbers they produced, and the presentation script. This page explains how it
fits together so you can run it, check it, or build on it.

---

## 1. The question we had to answer

Eniac wants to enter Brazil within a year and can't build a supply chain that
fast. Magist offers one. Two objections were on the table:

1. **Catalogue fit** — our catalogue is 100 % tech and skews expensive. Is Magist
   the right partner for that kind of product?
2. **Delivery speed** — fast delivery is our promise. Magist ships via the public
   Post Office. Is that fast enough?

We had one asset to settle this: a snapshot of Magist's database, 99,441 orders
from September 2016 to October 2018.

---

## 2. Getting it running (two minutes)

**Option A — no database install, no password.** This is the fast path and it
produces exactly the numbers in this repo.

```bash
git clone https://github.com/adminleo/eniac-magist-analysis.git
cd eniac-magist-analysis
python3 tools/mysql2sqlite.py /path/to/magist_dump.sql   # ~5 s
python3 tools/run_queries.py                             # ~1 s
```

All results land in `findings/results/` as CSV. Ask your own questions with:

```bash
sqlite3 -box magist.db "SELECT order_status, COUNT(*) FROM orders GROUP BY 1;"
```

**Option B — MySQL Workbench or the mysql CLI.** The files in `sql/` are plain
MySQL 8 and expect a schema named `magist`. Import the dump, then run them in
order. Nothing in `sql/` is SQLite-specific.

The dataset itself is **not** in this repo — it's bootcamp material and 65 MB.
So is `magist.db`, which you regenerate in five seconds.

---

## 3. How the analysis is organised

Each file in `sql/` answers one question. Read them in order and the argument
builds itself.

| File | Question it answers |
|---|---|
| `01_business_scope.sql` | Is Magist big enough to bother with? |
| `02_catalogue_fit.sql` | Does tech actually sell on this platform? |
| `03_price_positioning.sql` | Does *our* price class exist there? |
| `04_delivery_performance.sql` | How fast is delivery, and is it improving? |
| `05_customer_satisfaction.sql` | What does a late delivery cost us? |
| `06_payments_and_freight.sql` | Can Brazilians afford high-ticket, and what's shipping cost? |

`tools/run_queries.py` runs all six and writes one CSV per query.
`findings/FINDINGS.md` is the full write-up, with every figure traced back to the
query that produced it.

---

## 4. The argument in one page

**Magist is big enough.** 99,441 orders, R$13.6m, 3,095 sellers, and order volume
grew roughly 8× between January 2017 and August 2018. Not a small player.

**Concern 1 splits in two, and that's the whole insight.**

*Tech sells there.* It's 15.3 % of items and 13.9 % of revenue, and
`computers_accessories` is the **5th largest category on the entire platform** —
ahead of furniture, housewares and auto.

*But our price class doesn't exist.* The median item sells for **R$74.99**. The
99th percentile is **R$890**. Only 0.75 % of items — 846 out of 112,650 — reach
R$1,000. A 2018 iPhone in Brazil cost R$3,500–5,000, which is past the 99th
percentile of everything Magist has ever sold. On the supply side: of 3,095
sellers, only **202** have ever shipped a single item over R$1,000.

So Magist is an excellent fit for our **accessories** (R$75–230, exactly its
centre of gravity) and an unproven channel for flagship hardware.

**Concern 2: adequate, not fast — but improving sharply.**

Average delivery is **12.1 days** against a **23.4-day** promised window. Read
those together: Magist hits its promise 92 % of the time, but it does that by
promising three weeks. That's reliability bought with a conservative quote, not
with speed.

The trend is the better news: 2018-Q1 was 15.3 days with 14.6 % late; by 2018-Q3
it was **7.9 days**. Halved in two quarters.

Geography decides the experience: São Paulo (42 % of all orders) gets 8.3 days,
the northern states 20–24.

**Why this is really a brand question.** On-time orders average **4.29** stars.
Late ones average **2.55**, and 54.6 % of them are 1–2 stars. One missed date
makes a bad review five times more likely — against the exact thing Eniac sells
itself on.

**Two findings in our favour.** 73.9 % of payments are by credit card, and
baskets over R$1,000 average 6.5 instalments — the market does finance expensive
purchases. And freight is only **3.8 %** of value for items above R$1,000, versus
47 % under R$50: the Post Office deal is proportionally cheapest exactly where
our margin lives.

**Recommendation: sign, but not this deal.** Accessories first, 12–18 months
instead of three years with a delivery SLA, São Paulo and the Southeast before
going national.

---

## 5. Numbers worth memorising for the presentation

If you're presenting, these five carry the whole story:

- **R$74.99** — median item price on Magist
- **0.75 %** — share of items reaching R$1,000
- **12.1 days** against a **23.4-day** promise
- **7.9 days** — 2018-Q3, down from 15.3 in Q1
- **4.29 → 2.55** — review score, on time vs late

Say at most two numbers per slide. Everything else is there for the audience to
read.

---

## 6. What we deliberately did not claim

This matters if anyone challenges us.

The data shows what **Magist's current marketplace sellers** do. It does **not**
show what Magist could do as a fulfilment partner for us. The absence of
high-ticket tech may say more about who sells there today than about the
platform's capability.

We can't close that gap with this dataset, so we don't pretend to. Instead it's
the closing slide: before signing, ask Magist directly for delivery performance
on parcels above R$1,000, plus insurance and returns terms for high-value
electronics.

Other limits worth knowing: the snapshot ends mid-October 2018, so late-2018
months are partial and excluded from the growth series; revenue is
`order_items.price` and excludes freight; delivery analysis uses the 96,470
delivered orders that have a delivery timestamp.

---

## 7. If you want to add an analysis

Add a numbered file to `sql/`, write it in MySQL dialect, and prefix each query
with a `--` comment — the runner uses that comment as the result label and the
CSV filename. Then re-run `python3 tools/run_queries.py`.

One trap worth knowing if you touch the delivery queries: MySQL's
`TIMESTAMPDIFF(DAY, …)` returns **whole, truncated days**, while SQLite's
`julianday()` difference is fractional. The runner reproduces MySQL's behaviour
on purpose. Getting it wrong shifts the headline delivery figure from 12.1 to
12.6 days — small, but it's the number on the slide.

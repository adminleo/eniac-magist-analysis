# Findings — Magist database

**Dataset:** Magist snapshot, 99,441 orders placed between 2016-09-04 and 2018-10-17.
Monetary values are Brazilian reais (BRL). At 2018 rates roughly R$4.4 = €1.

Every figure below names the query that produced it. Raw outputs are in
[`results/`](results/); the queries are in [`../sql/`](../sql/).

---

## 1. Is Magist big enough to be worth it?

| Metric | Value |
|---|---|
| Orders | 99,441 |
| Order items | 112,650 |
| Active sellers | 3,095 |
| Distinct products | 32,951 |
| Product revenue (excl. freight) | R$ 13,591,644 |

*Source: `01_business_scope.sql` 1.1*

Growth is steep: **750 delivered orders in January 2017 → 6,351 in August 2018**,
roughly 8× in 20 months. Annual revenue went from R$5.96m (2017) to R$7.22m in
2018 — and 2018 is only captured through October.

*Source: `01_business_scope.sql` 1.2 / 1.3*

**Verdict: yes.** Magist is an established platform with real scale and momentum.

---

## 2. Concern 1 — Does the catalogue fit a high-end Apple retailer?

### 2a. Tech is present, and it is not marginal

| Category | Items | Revenue (BRL) | Avg price |
|---|---:|---:|---:|
| computers_accessories | 7,827 | 911,954 | 116.51 |
| telephony | 4,545 | 323,668 | 71.21 |
| computers | 203 | 222,963 | **1,098.34** |
| electronics | 2,767 | 160,247 | 57.91 |
| consoles_games | 1,137 | 157,465 | 138.49 |
| fixed_telephony | 264 | 59,583 | 225.69 |
| audio | 364 | 50,689 | 139.25 |
| tablets_printing_image | 83 | 7,528 | 90.70 |

Tech accounts for **15.3 % of items and 13.9 % of revenue**, and
`computers_accessories` is the **5th largest category on the whole platform** by
revenue, ahead of furniture, housewares and auto.

*Source: `02_catalogue_fit.sql` 2.1–2.3*

### 2b. But the price level does not match

| Measure | Value (BRL) |
|---|---:|
| Average item price | 120.65 |
| Median item price | **74.99** |
| 75th percentile | 134.90 |
| 90th percentile | 229.80 |
| 95th percentile | 349.90 |
| **99th percentile** | **890.00** |
| Maximum item price | 6,735.00 |

Only **2.88 %** of items sell for R$500 or more, and only **0.75 %** — 846 of
112,650 — reach R$1,000. A 2018 iPhone in Brazil retailed around R$3,500–5,000:
that is **beyond the 99th percentile** of everything Magist sells.

The supply side mirrors this: of 3,095 active sellers, only **202** have ever
sold a single item at R$1,000 or more. And `computers`, the one genuinely
high-ticket tech category (avg R$1,098), moved just **203 items in two years** —
about two per week across the entire platform.

*Source: `03_price_positioning.sql` 3.1–3.4*

**Verdict: split.** Magist is a strong fit for Eniac's **accessories** catalogue,
which sits exactly in the R$75–230 band where the platform lives. It is an
unproven channel for flagship hardware.

---

## 3. Concern 2 — Are deliveries fast enough?

### 3a. The headline numbers

| Measure | Value |
|---|---:|
| Average delivery time (purchase → customer) | **12.1 days** |
| Longest delivery observed | 209 days |
| Promised delivery window (avg) | 23.4 days |
| Delivered later than promised | **8.1 %** |
| Average days earlier than promised | 11.0 |

*Source: `04_delivery_performance.sql` 4.1–4.2*

Read those two lines together: Magist hits its promise 92 % of the time, but it
does so by **promising 23.4 days**. Reliability is bought with a conservative
quote, not with speed.

### 3b. It is improving sharply

| Quarter | Orders | Avg days | Late |
|---|---:|---:|---:|
| 2017-Q1 | 4,949 | 12.4 | 4.4 % |
| 2017-Q4 | 17,279 | 13.9 | 10.1 % |
| 2018-Q1 | 20,627 | **15.3** | **14.6 %** |
| 2018-Q2 | 19,643 | 10.3 | 5.1 % |
| 2018-Q3 | 12,507 | **7.9** | 7.5 % |

The 2017-Q4/2018-Q1 peak is a capacity wall during peak season. What matters is
what came after: average delivery **halved to 7.9 days** by 2018-Q3.

*Source: `04_delivery_performance.sql` 4.3*

### 3c. Geography decides the experience

| State | Orders | Avg days |
|---|---:|---:|
| SP (São Paulo) | 40,493 | **8.3** |
| MG / PR | 11,354 / 4,911 | 11.5 |
| RJ | 12,350 | 14.8 |
| … | | |
| BA | 3,256 | 19.3 |
| CE / MA / PA | 1,279 / 717 / 946 | 21.3 / 21.6 / **23.8** |

São Paulo alone is 42 % of all orders and is served nearly **3× faster** than the
northern states.

*Source: `04_delivery_performance.sql` 4.4*

**Verdict: adequate, not fast — and highly dependent on where the customer lives.**

---

## 4. What a late delivery costs

| Delivery | Orders | Avg review | 1–2 star reviews |
|---|---:|---:|---:|
| On time | 87,752 | **4.29** | 9.4 % |
| Late | 7,737 | **2.55** | **54.6 %** |

Platform average is 4.08 across 98,371 reviews.

*Source: `05_customer_satisfaction.sql` 5.1–5.2*

One missed date flips a customer from 4.29 to 2.55 and makes a 1–2 star review
**five times** more likely. For a company whose stated differentiator is the
warm, human customer relationship, this is the single most dangerous number in
the dataset.

---

## 5. Two findings that work in Eniac's favour

**The market can finance expensive purchases.** 73.9 % of payments are by credit
card, and instalment use scales with basket value: baskets of R$1,000+ average
**6.5 instalments**, with 60.7 % using six or more. Brazilian consumers do buy
high-ticket goods — they just spread the cost.

*Source: `06_payments_and_freight.sql` 6.1–6.2*

**Freight economics favour expensive goods.** Freight is 47.1 % of product value
for items under R$50, but only **3.8 %** for items above R$1,000. The Post Office
deal is proportionally cheapest exactly where Eniac's margin lives.

*Source: `06_payments_and_freight.sql` 6.3*

---

## 6. Recommendation

**Sign — but not the deal currently on the table.**

The data supports Magist as a market-entry vehicle and contradicts it as a
three-year, full-catalogue commitment.

1. **Enter with accessories, not flagship hardware.** Eniac's curated
   Apple-compatible accessories sit in the R$75–230 band that is Magist's proven
   centre of gravity, in a category (`computers_accessories`) already ranked 5th
   platform-wide. Flagship hardware sits beyond the 99th percentile of anything
   Magist has sold, with only 202 of 3,095 sellers having handled that price class.

2. **Shorten the commitment.** Three years is priced on 2018-Q1 performance —
   the worst quarter in the dataset. Delivery halved within two quarters, so the
   partner is improving fast, but the volatility is real. Push for 12–18 months
   with a renewal option, or keep three years with a delivery SLA and an exit
   clause tied to it.

3. **Phase the rollout geographically.** Launch in São Paulo and the Southeast,
   where 8.3-day delivery is defensible. Expanding to the North on the same
   service promise means 20+ day waits — and the review data shows exactly what
   that does.

**The honest caveat:** this dataset describes the behaviour of *Magist's current
marketplace sellers*, not Magist's capability as a logistics partner for Eniac.
The absence of high-ticket tech may reflect who sells on the platform today
rather than what it could ship tomorrow. Before signing, that has to be tested
directly — ask Magist for delivery performance on parcels above R$1,000 and for
insurance and returns terms on high-value electronics. It is the one question the
data cannot answer, and it is the one the deal turns on.

# Eniac × Magist — should we sign?

A data analysis deciding whether **Eniac**, a European online retailer of Apple
products and curated Apple-compatible accessories, should sign a three-year
contract with **Magist**, a Brazilian order-management and fulfilment SaaS, as
its entry route into the Brazilian market.

Two objections had to be settled with evidence:

1. Eniac's catalogue is 100 % tech and skews high-price. Is Magist the right
   partner for that?
2. Fast delivery is central to Eniac's promise. Magist ships through the public
   Post Office. Is that fast enough?

## Recommendation

> **Sign — but not the deal currently on the table.**
>
> Enter with the **accessories** catalogue rather than flagship hardware, cut the
> commitment from three years to **12–18 months** with a delivery SLA, and launch
> in **São Paulo and the Southeast** before going national.

## The evidence in one table

| Question | What the data says | Verdict |
|---|---|---|
| Is Magist big enough? | 99,441 orders · R$13.6m · 3,095 sellers · 8× order growth Jan-17 → Aug-18 | ✅ |
| Does tech sell there? | 15.3 % of items, 13.9 % of revenue; `computers_accessories` is the **5th** biggest category platform-wide | ✅ |
| Does the Apple price class exist? | Median item **R$74.99**, 99th percentile **R$890**. Only 0.75 % of items reach R$1,000. Only 202 of 3,095 sellers ever sold one | ❌ |
| Are deliveries fast? | **12.1 days** average against a **23.4-day** promised window; 8.1 % late | ⚠️ |
| Is it getting better? | 2018-Q1: 15.3 days / 14.6 % late → 2018-Q3: **7.9 days** / 7.5 % late | ✅ |
| What happens when it slips? | On-time reviews average **4.29**; late ones **2.55**, with 54.6 % at 1–2 stars | ⚠️ |
| Can customers afford high-ticket? | 73.9 % pay by credit card; R$1,000+ baskets average **6.5 instalments** | ✅ |
| Does freight hurt margin? | Freight is 47 % of value under R$50 but only **3.8 %** above R$1,000 | ✅ |

Full write-up with sources: **[findings/FINDINGS.md](findings/FINDINGS.md)**
Team onboarding — how to run it and how the argument is built: **[TEAM-GUIDE.md](TEAM-GUIDE.md)**

## Repository layout

```
sql/        Six analysis scripts, MySQL dialect — this is what runs in Workbench
findings/   FINDINGS.md (the argument) + results/ (CSV output of every query)
presentation/  Slide-by-slide script for the 4-minute delivery
tools/      Reproducibility: dump → SQLite converter and a query runner
```

## Reproducing the analysis

The dataset is **not** in this repository — it is bootcamp-provided and 65 MB.
Place `magist_dump.sql` where the converter can find it.

**Option A — MySQL (canonical).** Import the dump and run the files in `sql/`
in order; they are plain MySQL 8 and expect a schema named `magist`.

```bash
mysql -u root -p < magist_dump.sql
```

**Option B — local SQLite, no credentials needed.** Used to produce the numbers
in this repo:

```bash
python3 tools/mysql2sqlite.py          # magist_dump.sql -> magist.db
python3 tools/run_queries.py           # runs sql/*.sql, writes findings/results/*.csv
```

`run_queries.py` translates the MySQL queries to SQLite mechanically and
reproduces MySQL semantics where they differ — most importantly
`TIMESTAMPDIFF(DAY, …)`, which returns **whole, truncated days**. Getting that
wrong shifts the headline delivery figure by half a day.

## Limitations

- The snapshot covers **2016-09 to 2018-10**. Late-2018 months are partial and
  are excluded from the growth series.
- Revenue is `order_items.price` and **excludes freight**.
- Delivery analysis uses delivered orders with a non-null delivery timestamp
  (96,470 of 99,441).
- Most important: the data describes **Magist's current marketplace sellers**,
  not Magist's capability as a fulfilment partner for Eniac. The absence of
  high-ticket tech may say more about who sells there today than about what the
  platform could ship. That gap is called out explicitly in the findings and is
  the question to put to Magist before signing.

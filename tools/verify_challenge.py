"""Run the challenge/ SQL against the local SQLite copy and print the results.

Canonical is MySQL — challenge/*.sql is what runs in Workbench. This script
exists so the numbers quoted in those files' comments can be re-derived without
a MySQL install, which means it has to reproduce two pieces of MySQL semantics
that SQLite does not share:

1. The utf8mb4_0900_ai_ci collation makes LIKE accent-insensitive, so
   '%otimo%' matches "ótimo". SQLite's LIKE is accent-sensitive and would find
   981 of those reviews instead of 3,429 — no error, just a quieter answer.
   SQLite lets a user function named "like" replace the LIKE operator itself,
   so the whole dialect is fixed in one place rather than per query.

2. YEAR(ts) and MySQL's CONCAT have no SQLite equivalent; both are rewritten.

Usage:  python3 tools/verify_challenge.py [path/to/magist.db]
"""
import os, re, sqlite3, sys, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB   = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "magist.db")
CH   = os.path.join(ROOT, "challenge")

STATES = [('Acre','AC'),('Alagoas','AL'),('Amazonas','AM'),('Amapá','AP'),('Bahía','BA'),
          ('Ceará','CE'),('Distrito Federal','DF'),('Espirito Santo','ES'),('Goiás','GO'),
          ('Maranhão','MA'),('Minas Geraís','MG'),('Mato Grosso do Sul','MS'),('Mato Grosso','MT'),
          ('Pará','PA'),('Paraíba','PB'),('Pernambuco','PE'),('Piauí','PI'),('Paraná','PR'),
          ('Rio de Janeiro','RJ'),('Rio Grande do Norte','RN'),('Rondônia','RO'),('Roraima','RR'),
          ('Rio Grande do Sul','RS'),('Santa Catarina','SC'),('Sergipe','SE'),('São Paulo','SP'),
          ('Tocantins','TO')]


def fold(s):
    """Case-fold and strip diacritics — what utf8mb4_0900_ai_ci does."""
    if s is None:
        return ''
    return ''.join(c for c in unicodedata.normalize('NFD', str(s).lower())
                   if unicodedata.category(c) != 'Mn')


def ai_like(pattern, value, escape=None):
    """Stand in for the LIKE operator with an accent-insensitive collation.

    Built character by character rather than with re.escape + replace: since
    Python 3.7 re.escape leaves '%' and '_' alone, so the obvious version
    produces a pattern that matches nothing and reports it as zero hits.
    """
    if value is None or pattern is None:
        return None
    rx = ''.join('.*' if c == '%' else '.' if c == '_' else re.escape(c)
                 for c in fold(pattern))
    return 1 if re.fullmatch(rx, fold(value), re.S) else 0


def connect():
    db = sqlite3.connect(DB)
    db.create_function("like", 2, ai_like)
    db.create_function("like", 3, ai_like)
    db.execute("DROP TABLE IF EXISTS states")
    db.execute("CREATE TABLE states (state varchar(40), short char(2) PRIMARY KEY)")
    db.executemany("INSERT INTO states VALUES (?,?)", STATES)
    db.commit()
    return db


def to_sqlite(sql):
    sql = re.sub(r'^\s*USE\s+\w+\s*;?\s*$', '', sql, flags=re.I | re.M)
    sql = re.sub(r"YEAR\(\s*([\w.]+)\s*\)", r"CAST(strftime('%Y', \1) AS INTEGER)", sql, flags=re.I)
    while True:                                    # CONCAT(a,b,c) -> (a || b || c)
        i = sql.upper().find("CONCAT(")
        if i == -1:
            break
        j, depth = i + 7, 1
        while j < len(sql) and depth:
            if sql[j] == '(':
                depth += 1
            elif sql[j] == ')':
                depth -= 1
            j += 1
        inner, parts, d, cur = sql[i + 7:j - 1], [], 0, ''
        for ch in inner:
            if ch == '(':
                d += 1
            if ch == ')':
                d -= 1
            if ch == ',' and d == 0:
                parts.append(cur.strip()); cur = ''
            else:
                cur += ch
        parts.append(cur.strip())
        sql = sql[:i] + '(' + ' || '.join(parts) + ')' + sql[j:]
    return sql


def split_statements(text):
    """Semicolons that terminate a statement — not those inside comments or
    string literals, which a naive split(';') cannot tell apart."""
    out, cur, i, n = [], '', 0, len(text)
    while i < n:
        ch = text[i]
        if text[i:i + 2] == '--':
            j = text.find('\n', i); j = n if j == -1 else j
            cur += text[i:j]; i = j; continue
        if ch == "'":
            j = i + 1
            while j < n:
                if text[j] == "'" and text[j:j + 2] != "''":
                    break
                j += 2 if text[j:j + 2] == "''" else 1
            cur += text[i:j + 1]; i = j + 1; continue
        if ch == ';':
            out.append(cur); cur = ''; i += 1; continue
        cur += ch; i += 1
    out.append(cur)
    return out


def label_of(stmt):
    """The numbered heading a statement sits under.

    A chunk starts after the previous statement's semicolon, so it opens with
    that statement's trailing commentary; taking the first comment line labels
    every result with the previous question. Prefer a '-- 1.2 ...' heading.
    """
    comments = [l.strip()[2:].strip() for l in stmt.splitlines() if l.strip().startswith('--')]
    numbered = [c for c in comments if re.match(r'\d+\.\d+\s', c)]
    if numbered:
        return numbered[-1]
    body = [l.strip() for l in stmt.splitlines()
            if l.strip() and not l.strip().startswith('--')]
    return body[0][:70] if body else '(query)'


def show(cur, rows, limit=10):
    if not rows:
        print("      (no rows)"); return
    head = [d[0] for d in cur.description]
    w = [max(len(str(h)), *(len(str(r[i])) for r in rows)) for i, h in enumerate(head)]
    print("      " + "  ".join(str(h).ljust(w[i]) for i, h in enumerate(head)))
    for r in rows[:limit]:
        print("      " + "  ".join(str(v).ljust(w[i]) for i, v in enumerate(r)))
    if len(rows) > limit:
        print(f"      … {len(rows) - limit} more rows")


# The body of the stored procedure, which SQLite cannot hold as a procedure.
PROCEDURE_BODY = """
SELECT ? AS state, ? AS category, ? AS year,
       COUNT(*) AS reviews, ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM order_reviews r
JOIN orders    o ON o.order_id        = r.order_id
JOIN customers c ON c.customer_id     = o.customer_id
JOIN geo       g ON g.zip_code_prefix = c.customer_zip_code_prefix
JOIN states    s ON s.short           = g.state
WHERE s.state = ?1 AND o.order_status = 'delivered'
  AND CAST(strftime('%Y', o.order_purchase_timestamp) AS INTEGER) = ?3
  AND EXISTS (SELECT 1 FROM order_items oi
              JOIN products p ON p.product_id = oi.product_id
              JOIN product_category_name_translation t
                ON t.product_category_name = p.product_category_name
              WHERE oi.order_id = o.order_id
                AND t.product_category_name_english = ?2)
"""

CALLS = [('São Paulo', 'health_beauty', 2018), ('São Paulo', 'computers_accessories', 2017),
         ('Rio de Janeiro', 'bed_bath_table', 2018), ('Minas Geraís', 'toys', 2018),
         ('Roraima', 'telephony', 2018), ('Acre', 'furniture_decor', 2016)]


def main():
    if not os.path.exists(DB):
        sys.exit(f"{DB} not found — build it first with tools/mysql2sqlite.py")
    db = connect()
    fails = 0

    print("== challenge/01_reviews_by_state.sql")
    text = open(os.path.join(CH, "01_reviews_by_state.sql")).read()
    for stmt in split_statements(text):
        if not re.sub(r'(--[^\n]*|\s)', '', stmt):
            continue
        print(f"\n   {label_of(stmt)}")
        try:
            cur = db.execute(to_sqlite(stmt))
            show(cur, cur.fetchall())
        except Exception as e:
            fails += 1
            print(f"      FAIL: {e}")

    print("\n== challenge/02_kpi_procedure.sql — procedure body, one call per row")
    for st, cat, yr in CALLS:
        try:
            row = db.execute(PROCEDURE_BODY, (st, cat, yr)).fetchone()
            print(f"   {st:16s} {cat:24s} {yr}   n={row[3]:<6d} avg={row[4]}")
        except Exception as e:
            fails += 1
            print(f"   {st} / {cat} / {yr}  FAIL: {e}")

    print(f"\n{'FAILURES: ' + str(fails) if fails else 'All statements ran.'}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())

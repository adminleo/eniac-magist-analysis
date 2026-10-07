"""Fuehrt alle sql/*.sql gegen die lokale SQLite-Kopie aus und schreibt CSVs.

Kanonisch sind die MySQL-Queries in sql/ — das ist, was das Team in Workbench
laeuft. Fuer die Verifikation uebersetzt dieses Skript sie mechanisch nach
SQLite. Die Uebersetzung bildet MySQL-Semantik nach, insbesondere:
TIMESTAMPDIFF(DAY, ...) liefert GANZE Tage (abgeschnitten) — deshalb CAST(... AS INTEGER).
"""
import csv, os, re, sqlite3, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB   = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "magist.db")
OUT  = os.path.join(ROOT, "findings", "results")

def to_sqlite(sql):
    sql = re.sub(r'^\s*USE\s+\w+\s*;?\s*$', '', sql, flags=re.I | re.M)
    sql = re.sub(r"TIMESTAMPDIFF\(\s*DAY\s*,\s*([\w.]+)\s*,\s*([\w.]+)\s*\)",
                 r"CAST(julianday(\2) - julianday(\1) AS INTEGER)", sql, flags=re.I)
    sql = re.sub(r"DATE_FORMAT\(\s*([\w.]+)\s*,\s*'%Y-%m'\s*\)", r"substr(\1,1,7)", sql, flags=re.I)
    sql = re.sub(r"DATE_FORMAT\(\s*([\w.]+)\s*,\s*'%Y'\s*\)",    r"substr(\1,1,4)", sql, flags=re.I)
    sql = re.sub(r"QUARTER\(\s*([\w.]+)\s*\)",
                 r"((CAST(substr(\1,6,2) AS INTEGER)-1)/3+1)", sql, flags=re.I)
    # CONCAT(a, b, c) -> (a || b || c), via a paren-counting scanner so that
    # nested arguments such as CONCAT(substr(x,1,4), '-Q', (...)) are handled safely.
    while True:
        i = sql.upper().find("CONCAT(")
        if i == -1:
            break
        j, depth = i + len("CONCAT("), 1
        while j < len(sql) and depth:
            if sql[j] == '(': depth += 1
            elif sql[j] == ')': depth -= 1
            j += 1
        inner = sql[i + len("CONCAT("): j - 1]
        parts, d, cur = [], 0, ''
        for ch in inner:
            if ch == '(': d += 1
            if ch == ')': d -= 1
            if ch == ',' and d == 0:
                parts.append(cur.strip()); cur = ''
            else:
                cur += ch
        parts.append(cur.strip())
        sql = sql[:i] + '(' + ' || '.join(parts) + ')' + sql[j:]
    return sql

def percentiles(db):
    rows = [r[0] for r in db.execute("SELECT price FROM order_items ORDER BY price")]
    n = len(rows)
    p = lambda f: round(rows[int(n * f)], 2)
    return ["p50","p75","p90","p95","p99"], [[p(.50), p(.75), p(.90), p(.95), p(.99)]]

def main():
    os.makedirs(OUT, exist_ok=True)
    db = sqlite3.connect(DB)
    for fn in sorted(f for f in os.listdir(os.path.join(ROOT, "sql")) if f.endswith(".sql")):
        text = open(os.path.join(ROOT, "sql", fn)).read()
        blocks = [b.strip() for b in text.split(";") if b.strip() and not
                  all(l.strip().startswith("--") or not l.strip() for l in b.splitlines())]
        for i, block in enumerate(blocks, 1):
            label = next((l.strip("- ").strip() for l in block.splitlines()
                          if l.strip().startswith("--")), f"query {i}")
            if not re.sub(r'(--[^\n]*|\s|USE\s+\w+)', '', block):
                continue
            if "PERCENTILE_CONT" in block.upper():
                hdr, rows = percentiles(db)          # SQLite kennt PERCENTILE_CONT nicht
            else:
                cur = db.execute(to_sqlite(block))
                hdr = [d[0] for d in cur.description]; rows = cur.fetchall()
            out = os.path.join(OUT, f"{fn[:-4]}_{i:02d}.csv")
            with open(out, "w", newline="") as f:
                w = csv.writer(f); w.writerow(hdr); w.writerows(rows)
            print(f"\n[{fn} #{i}] {label}")
            print("   " + " | ".join(hdr))
            for r in rows[:12]:
                print("   " + " | ".join(f"{v:,.2f}" if isinstance(v, float)
                                         else f"{v:,}" if isinstance(v, int) else str(v) for v in r))
            if len(rows) > 12: print(f"   … {len(rows)-12} weitere Zeilen")

if __name__ == "__main__":
    main()

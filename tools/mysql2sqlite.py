"""Stream a MySQL dump into SQLite.

Values are parsed and inserted as parameters, so MySQL's backslash escaping
never reaches SQLite's parser.

Usage:
    python3 tools/mysql2sqlite.py [dump.sql] [out.db]

Defaults: looks for magist_dump.sql in the repo root, then ~/Downloads;
writes magist.db into the repo root.
"""
import re, sqlite3, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def default_src():
    for c in (os.path.join(ROOT, "magist_dump.sql"),
              os.path.expanduser("~/Downloads/magist_dump.sql")):
        if os.path.exists(c):
            return c
    sys.exit("magist_dump.sql not found — pass the path as the first argument.")

SRC = sys.argv[1] if len(sys.argv) > 1 else default_src()
DST = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "magist.db")
print(f"reading  {SRC}\nwriting  {DST}")
if os.path.exists(DST): os.remove(DST)
db = sqlite3.connect(DST)
db.execute("PRAGMA journal_mode=OFF"); db.execute("PRAGMA synchronous=OFF")

TYPE = [(r'\bint\b.*?(?=,|$)', 'INTEGER'), (r'\bbigint\b.*', 'INTEGER'),
        (r'\bsmallint\b.*', 'INTEGER'), (r'\btinyint\b.*', 'INTEGER'),
        (r'\bdouble\b.*', 'REAL'), (r'\bfloat\b.*', 'REAL'),
        (r'\bdecimal\([\d,]+\).*', 'REAL')]

def conv_create(block):
    name = re.search(r'CREATE TABLE `([^`]+)`', block).group(1)
    body = block[block.index('(')+1 : block.rindex(')')]
    cols, depth, cur = [], 0, ''
    for ch in body:                      # split top-level commas
        if ch == '(': depth += 1
        if ch == ')': depth -= 1
        if ch == ',' and depth == 0: cols.append(cur.strip()); cur = ''
        else: cur += ch
    cols.append(cur.strip())
    keep, names = [], []
    for c in cols:
        if re.match(r'(UNIQUE\s+)?KEY\s', c, re.I) or c.upper().startswith('CONSTRAINT'):
            continue
        if c.upper().startswith('PRIMARY KEY'):
            keep.append(c.replace('`','')); continue
        m = re.match(r'`([^`]+)`\s+(.*)', c)
        if not m: continue
        col, rest = m.group(1), m.group(2)
        rest = re.sub(r'COLLATE \S+|CHARACTER SET \S+|unsigned|AUTO_INCREMENT', '', rest, flags=re.I)
        for pat, repl in TYPE: rest = re.sub(pat, repl, rest, flags=re.I)
        rest = re.sub(r'\bvarchar\([\d]+\)|\bchar\([\d]+\)|\btext\b|\bdatetime\b|\btimestamp\b|\bdate\b',
                      'TEXT', rest, flags=re.I)
        names.append(col); keep.append(f'"{col}" {rest.strip()}')
    db.execute(f'CREATE TABLE "{name}" ({", ".join(keep)})')
    return name, names

def split_values(s):
    """Yield one tuple of python values per (...) group."""
    i, n = 0, len(s)
    while i < n:
        while i < n and s[i] != '(': i += 1
        if i >= n: return
        i += 1; row, cur, q = [], '', False
        while i < n:
            ch = s[i]
            if q:
                if ch == '\\':
                    nxt = s[i+1]
                    cur += {'n':'\n','t':'\t','r':'\r','0':'\0'}.get(nxt, nxt); i += 2; continue
                if ch == "'":
                    if i+1 < n and s[i+1] == "'": cur += "'"; i += 2; continue
                    q = False; i += 1; continue
                cur += ch; i += 1; continue
            if ch == "'": q = True; cur = ''; i += 1; continue
            if ch == ',': row.append(cur.strip()); cur = ''; i += 1; continue
            if ch == ')': row.append(cur.strip()); i += 1; break
            cur += ch; i += 1
        yield [None if v == 'NULL' else v for v in row]

tables, buf, in_create, total = {}, '', False, 0
with open(SRC, encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('CREATE TABLE'): in_create, buf = True, line; continue
        if in_create:
            buf += line
            if line.startswith(')'):
                t, cols = conv_create(buf); tables[t] = cols; in_create = False
            continue
        if line.startswith('INSERT INTO'):
            t = re.match(r'INSERT INTO `([^`]+)`', line).group(1)
            cols = tables[t]
            rows = list(split_values(line[line.index(' VALUES ')+8:]))
            rows = [r for r in rows if len(r) == len(cols)]
            db.executemany(f'INSERT INTO "{t}" VALUES ({",".join("?"*len(cols))})', rows)
            total += len(rows)
db.commit()

# Indexes: the dump's KEY/CONSTRAINT lines are dropped during conversion, and
# without these the customer -> geo join in 04 takes minutes instead of seconds.
for ddl in (
    "CREATE INDEX IF NOT EXISTS ix_oi_product ON order_items(product_id)",
    "CREATE INDEX IF NOT EXISTS ix_oi_order   ON order_items(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_p_id       ON products(product_id)",
    "CREATE INDEX IF NOT EXISTS ix_pc_name    ON product_category_name_translation(product_category_name)",
    "CREATE INDEX IF NOT EXISTS ix_o_id       ON orders(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_o_cust     ON orders(customer_id)",
    "CREATE INDEX IF NOT EXISTS ix_c_id       ON customers(customer_id)",
    "CREATE INDEX IF NOT EXISTS ix_c_zip      ON customers(customer_zip_code_prefix)",
    "CREATE INDEX IF NOT EXISTS ix_g_zip      ON geo(zip_code_prefix)",
    "CREATE INDEX IF NOT EXISTS ix_r_order    ON order_reviews(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_pay_order  ON order_payments(order_id)",
):
    db.execute(ddl)
db.commit()
print("rows inserted:", total)
for (t,) in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
    print(f"  {t:36s} {db.execute(f'SELECT COUNT(*) FROM \"{t}\"').fetchone()[0]:>8,}")

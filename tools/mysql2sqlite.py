"""Stream a MySQL dump into SQLite.
parameters, so MySQL's backslash escaping never reaches SQLite's parser."""
import re, sqlite3, sys, os

SRC = os.path.expanduser("~/Downloads/magist_dump.sql")
DST = "/private/tmp/claude-501/-Users-leonardobornhausser-Projects-git/c8af520f-d611-4da6-af19-4114dd85f597/scratchpad/magist.db"
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
print("rows inserted:", total)
for (t,) in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
    print(f"  {t:36s} {db.execute(f'SELECT COUNT(*) FROM \"{t}\"').fetchone()[0]:>8,}")

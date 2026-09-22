#!/usr/bin/env python3
"""Static/SQLite schema audit for the TRINEX D1 backend."""
from pathlib import Path
import re, sqlite3, sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / 'backend' / 'migrations'
INDEX_JS = ROOT / 'backend' / 'src' / 'index.js'

sql = '\n'.join(p.read_text(encoding='utf-8') for p in sorted(MIGRATIONS.glob('*.sql')))
conn = sqlite3.connect(':memory:')
conn.executescript(sql)
conn.execute('PRAGMA foreign_keys=ON')

tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")}
if not tables:
    raise SystemExit('No application tables found')

# Every declared FK must point to an existing table.
for table in sorted(tables):
    for row in conn.execute(f'PRAGMA foreign_key_list("{table}")'):
        target = row[2]
        if target not in tables:
            raise SystemExit(f'Broken FK: {table} -> {target}')

# Required structural invariants.
sessions_sql = conn.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='sessions'").fetchone()[0]
if 'student_id' not in sessions_sql or 'staff_user_id' not in sessions_sql:
    raise SystemExit('sessions identity columns missing')

idx_names = [r[1] for r in conn.execute("SELECT type,name FROM sqlite_master WHERE type='index'")]
if len(idx_names) != len(set(idx_names)):
    raise SystemExit('Duplicate SQLite index names detected')

source = INDEX_JS.read_text(encoding='utf-8')
if 'SELECT * FROM' in source:
    # SELECT * remains allowed for authenticated/admin internals, but public
    # endpoints must serialize explicit fields. This check prevents accidental
    # raw SELECT * in public material/content SQL blocks.
    for marker in ('async function publicContentDetail', 'async function publicList', 'async function publicMaterials'):
        start = source.find(marker)
        end = source.find('\nasync function ', start + 10)
        block = source[start:end if end != -1 else len(source)]
        if re.search(r'SELECT\s+\*\s+FROM', block, re.I):
            raise SystemExit(f'Raw SELECT * found in public handler: {marker}')

print(f'backend schema audit: {len(tables)} tables, {len(idx_names)} indexes, foreign keys OK')

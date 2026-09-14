from pathlib import Path
import re, sqlite3, sys

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / 'backend'
SOURCE = (BACKEND / 'src/index.js').read_text(encoding='utf-8')
errors = []

# Regression guards for schema mismatches found during the Phase 1 audit.
# announcements intentionally has no updated_by column, and schedules intentionally
# has no created_at column in the current D1 schema. These must never be referenced
# by the admin CRUD contract.
SCHEMA_ABSENT_COLUMNS = {
    'announcements': {'updated_by'},
    'schedules': {'created_at'},
}

TABLES = ['news','announcements','activities','achievements','subjects','materials','schedules','students','badges']
CONTENT = ['news','activities','announcements','achievements']
ACTIVE = ['materials','schedules','students','subjects','badges']

# Verify every field exposed by ADMIN_FIELDS actually exists in the final D1 schema.
try:
    con = sqlite3.connect(':memory:')
    for path in sorted((BACKEND / 'migrations').glob('*.sql')):
        con.executescript(path.read_text(encoding='utf-8'))

    for table in TABLES:
        match = re.search(rf"\b{re.escape(table)}:\s*\[([^\]]*)\]", SOURCE)
        if not match:
            errors.append(f'Missing ADMIN_FIELDS entry: {table}')
            continue
        fields = re.findall(r"['\"]([^'\"]+)['\"]", match.group(1))
        actual = {row[1] for row in con.execute(f'PRAGMA table_info({table})')}
        forbidden = SCHEMA_ABSENT_COLUMNS.get(table, set())
        if actual & forbidden:
            errors.append(f'{table}: schema unexpectedly contains columns that the current CRUD contract excludes: {sorted(actual & forbidden)}')
        missing = [f for f in fields if f not in actual]
        if missing:
            errors.append(f'{table}: ADMIN_FIELDS contains unknown columns: {missing}')

        select_match = re.search(rf"\b{re.escape(table)}:\s*['\"]([^'\"]+)['\"]", SOURCE[SOURCE.find('const ADMIN_SELECT_COLUMNS'):])
        if not select_match:
            errors.append(f'Missing ADMIN_SELECT_COLUMNS entry: {table}')
        else:
            selected = [x.strip() for x in select_match.group(1).split(',')]
            missing_select = [f for f in selected if f not in actual]
            if missing_select:
                errors.append(f'{table}: ADMIN_SELECT_COLUMNS contains unknown columns: {missing_select}')
            forbidden_select = sorted(set(selected) & forbidden)
            if forbidden_select:
                errors.append(f'{table}: ADMIN_SELECT_COLUMNS references excluded columns: {forbidden_select}')
except Exception as exc:
    errors.append(f'Schema/contract check failed: {exc}')

# Content must use the status lifecycle; operational records use active=0.
if "const CONTENT_TABLES = Object.freeze(new Set(['news', 'activities', 'announcements', 'achievements']))" not in SOURCE:
    errors.append('CONTENT_TABLES contract is missing or incomplete')
if "UPDATE ${table} SET status='archived'" not in SOURCE:
    errors.append('Content DELETE must archive by status')
if "UPDATE ${table} SET active=0 WHERE id=? AND active=1" not in SOURCE:
    errors.append('Operational soft-delete contract is missing')

# Execute the exact DELETE SQL shapes against a real SQLite schema with representative rows.
try:
    con = sqlite3.connect(':memory:')
    con.execute('PRAGMA foreign_keys=ON')
    for path in sorted((BACKEND / 'migrations').glob('*.sql')):
        con.executescript(path.read_text(encoding='utf-8'))

    con.execute("INSERT INTO roles(id,name) VALUES('role-1','super_admin')")
    con.execute("INSERT INTO staff_users(id,user_id,email,display_name,role_id) VALUES('staff-1','admin-test','admin@example.invalid','Test Admin','role-1')")
    con.execute("INSERT INTO departments(id,name_ar,code) VALUES('dep-1','قسم تجريبي','TEST')")
    con.execute("INSERT INTO semesters(id,name_ar,academic_year,number) VALUES('sem-1','فصل تجريبي','2026/2027',1)")
    con.execute("INSERT INTO students(id,student_number,full_name,department_id) VALUES('stu-1','S-1','طالب تجريبي','dep-1')")
    con.execute("INSERT INTO subjects(id,semester_id,department_id,name_ar) VALUES('sub-1','sem-1','dep-1','مادة تجريبية')")
    con.execute("INSERT INTO badges(id,name_ar,rule_type) VALUES('badge-1','شارة تجريبية','level')")

    # Validate content update attribution matches the actual schema.
    update_rows = {
        'news': "UPDATE news SET title=?, updated_by=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
        'activities': "UPDATE activities SET title=?, updated_by=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
        'announcements': "UPDATE announcements SET title=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
        'achievements': "UPDATE achievements SET title=?, updated_by=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
    }

    for table in CONTENT:
        if table == 'news':
            con.execute("INSERT INTO news(id,title,body,status,created_by) VALUES('test-news','t','b','published','staff-1')")
        elif table == 'activities':
            con.execute("INSERT INTO activities(id,title,body,status,created_by) VALUES('test-activities','t','b','published','staff-1')")
        elif table == 'announcements':
            con.execute("INSERT INTO announcements(id,title,body,status,created_by) VALUES('test-announcements','t','b','published','staff-1')")
        elif table == 'achievements':
            con.execute("INSERT INTO achievements(id,title,status,created_by) VALUES('test-achievements','t','published','staff-1')")

        if table in {'news','activities','achievements'}:
            con.execute(update_rows[table], ('updated', 'staff-1', f'test-{table}'))
        else:
            con.execute(update_rows[table], ('updated', f'test-{table}'))

        if table in {'news','activities','achievements'}:
            con.execute(f"UPDATE {table} SET status='archived', updated_by=?, updated_at=CURRENT_TIMESTAMP WHERE id=? AND status!='archived'", ('staff-1', f'test-{table}'))
        else:
            con.execute(f"UPDATE {table} SET status='archived', updated_at=CURRENT_TIMESTAMP WHERE id=? AND status!='archived'", (f'test-{table}',))
        row = con.execute(f"SELECT status FROM {table} WHERE id=?", (f'test-{table}',)).fetchone()
        if not row or row[0] != 'archived':
            errors.append(f'{table}: archive SQL did not produce archived state')

    active_rows = {
        'subjects': "UPDATE subjects SET active=0 WHERE id=? AND active=1",
        'materials': "UPDATE materials SET active=0 WHERE id=? AND active=1",
        'schedules': "UPDATE schedules SET active=0 WHERE id=? AND active=1",
        'students': "UPDATE students SET active=0 WHERE id=? AND active=1",
        'badges': "UPDATE badges SET active=0 WHERE id=? AND active=1",
    }
    con.execute("INSERT INTO materials(id,subject_id,title) VALUES('mat-1','sub-1','ملف تجريبي')")
    con.execute("INSERT INTO schedules(id,semester_id,department_id,day_of_week,start_time,end_time) VALUES('sch-1','sem-1','dep-1',1,'08:00','09:00')")
    for table, sql in active_rows.items():
        ident = {'subjects':'sub-1','materials':'mat-1','schedules':'sch-1','students':'stu-1','badges':'badge-1'}[table]
        con.execute(sql, (ident,))
        row = con.execute(f"SELECT active FROM {table} WHERE id=?", (ident,)).fetchone()
        if not row or row[0] != 0:
            errors.append(f'{table}: active soft-delete SQL did not deactivate row')
except Exception as exc:
    errors.append(f'CRUD SQL execution check failed: {exc}')

if errors:
    print('ADMIN CRUD CHECK FAILED')
    for error in errors:
        print(' -', error)
    sys.exit(1)

print('ADMIN CRUD CHECK PASSED: schema fields, projections, content archive, and active soft-delete contracts')

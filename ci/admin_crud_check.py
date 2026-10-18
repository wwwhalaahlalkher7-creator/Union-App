from pathlib import Path
import re, sqlite3, sys

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / 'backend'
SOURCE = '\n'.join(p.read_text(encoding='utf-8') for p in (BACKEND / 'src').rglob('*.js'))
errors = []

# Regression guards for schema mismatches found during the Phase 1 audit.
# announcements intentionally has no updated_by column, and schedules intentionally
# has no created_at column in the current D1 schema. These must never be referenced
# by the admin CRUD contract.
SCHEMA_ABSENT_COLUMNS = {
    'announcements': {'updated_by'},
    'schedules': {'created_at'},
}

TABLES = ['news','announcements','events','achievements','subjects','materials','schedules','students']
CONTENT = ['news','events','announcements','achievements']
ACTIVE = ['materials','schedules','students','subjects']

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
            raw_selected = [x.strip() for x in select_match.group(1).split(',')]
            # SELECT projections may contain safe derived fields (e.g. registered).
            selected = [x.split(' AS ')[-1].strip() if ' AS ' in x.upper() else x for x in raw_selected]
            missing_select = [f for f in selected if f not in actual and f != 'registered']
            if missing_select:
                errors.append(f'{table}: ADMIN_SELECT_COLUMNS contains unknown columns: {missing_select}')
            forbidden_select = sorted(set(selected) & forbidden)
            if forbidden_select:
                errors.append(f'{table}: ADMIN_SELECT_COLUMNS references excluded columns: {forbidden_select}')
except Exception as exc:
    errors.append(f'Schema/contract check failed: {exc}')

# Badge definitions are application-owned and must never be exposed as an admin CRUD resource.
if re.search(r"\bbadges\s*:\s*['\"]badges['\"]", SOURCE):
    errors.append('badges must not be exposed through the admin CRUD resource map')
if re.search(r"\bbadges\s*:\s*\[", SOURCE):
    errors.append('badges must not be present in ADMIN_FIELDS')

# Current admin contract: dashboard DELETE is a true hard delete.
# Content records are permanently removed after dependent comments/reactions are cleaned.
# Operational records are also hard-deleted; active=0 remains only for the separate
# disable/deactivate controls and must not be used as the DELETE contract.
expected_content = {'news','events','announcements','achievements'}
content_match = re.search(r"const CONTENT_TABLES = Object.freeze\(new Set\(\[(.*?)\]\)\);", SOURCE, re.S)
if not content_match:
    errors.append('CONTENT_TABLES contract is missing')
else:
    declared_content = set(re.findall(r"['\"]([^'\"]+)['\"]", content_match.group(1)))
    if declared_content != expected_content:
        errors.append(f'CONTENT_TABLES contract mismatch: expected {sorted(expected_content)}, got {sorted(declared_content)}')
if "DELETE FROM ${table} WHERE id=?" not in SOURCE:
    errors.append('Admin hard-delete SQL contract is missing')
if "mode:'hard_delete'" not in SOURCE:
    errors.append('Hard-delete audit contract is missing')

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

    # Validate content update attribution matches the actual schema.
    update_rows = {
        'news': "UPDATE news SET title=?, updated_by=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
        'events': "UPDATE events SET title=?, updated_by=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
        'announcements': "UPDATE announcements SET title=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
        'achievements': "UPDATE achievements SET title=?, updated_by=?, updated_at=CURRENT_TIMESTAMP WHERE id=?",
    }

    for table in CONTENT:
        if table == 'news':
            con.execute("INSERT INTO news(id,title,body,status,created_by) VALUES('test-news','t','b','published','staff-1')")
        elif table == 'events':
            con.execute("INSERT INTO events(id,title,body,status,created_by) VALUES('test-events','t','b','published','staff-1')")
        elif table == 'announcements':
            con.execute("INSERT INTO announcements(id,title,body,status,created_by) VALUES('test-announcements','t','b','published','staff-1')")
        elif table == 'achievements':
            con.execute("INSERT INTO achievements(id,title,status,created_by) VALUES('test-achievements','t','published','staff-1')")

        if table in {'news','events','achievements'}:
            con.execute(update_rows[table], ('updated', 'staff-1', f'test-{table}'))
        else:
            con.execute(update_rows[table], ('updated', f'test-{table}'))

        con.execute(f"DELETE FROM {table} WHERE id=?", (f'test-{table}',))
        row = con.execute(f"SELECT id FROM {table} WHERE id=?", (f'test-{table}',)).fetchone()
        if row is not None:
            errors.append(f'{table}: hard-delete SQL did not remove row')

    hard_delete_rows = {
        'subjects': "DELETE FROM subjects WHERE id=?",
        'materials': "DELETE FROM materials WHERE id=?",
        'schedules': "DELETE FROM schedules WHERE id=?",
        'students': "DELETE FROM students WHERE id=?",
    }
    # Badges are an internal fixed system and are intentionally not dashboard-deletable.
    con.execute("INSERT INTO materials(id,subject_id,title) VALUES('mat-1','sub-1','ملف تجريبي')")
    con.execute("INSERT INTO schedules(id,semester_id,department_id,day_of_week,start_time,end_time) VALUES('sch-1','sem-1','dep-1',1,'08:00','09:00')")
    for table, sql in hard_delete_rows.items():
        ident = {'subjects':'sub-1','materials':'mat-1','schedules':'sch-1','students':'stu-1'}[table]
        # Subjects/materials are referenced by dependent test rows, so clean the minimal
        # dependencies before executing the exact hard-delete shape.
        if table == 'subjects':
            con.execute("DELETE FROM materials WHERE subject_id=?", (ident,))
            con.execute("DELETE FROM schedules WHERE subject_id=?", (ident,))
        elif table == 'students':
            pass
        con.execute(sql, (ident,))
        row = con.execute(f"SELECT id FROM {table} WHERE id=?", (ident,)).fetchone()
        if row is not None:
            errors.append(f'{table}: hard-delete SQL did not remove row')
except Exception as exc:
    errors.append(f'CRUD SQL execution check failed: {exc}')

if errors:
    print('ADMIN CRUD CHECK FAILED')
    for error in errors:
        print(' -', error)
    sys.exit(1)

print('ADMIN CRUD CHECK PASSED: schema fields, projections, and hard-delete contracts')

# Content DELETE must be a hard delete. Archive is not a supported admin delete mode.
admin_js = (ROOT / "backend/src/admin.js").read_text(encoding="utf-8")
content_delete_region = admin_js[admin_js.find("if (table === 'announcements')"):admin_js.find("if (table === 'comments')")]
assert "mode:'archive'" not in content_delete_region, "content DELETE must not use archive mode"
assert "DELETE FROM announcements WHERE id=?" in content_delete_region, "announcement DELETE must be hard delete"
assert "DELETE FROM ${table} WHERE id=?" in content_delete_region, "content DELETE must be hard delete"
print("PASS hard-delete content policy")

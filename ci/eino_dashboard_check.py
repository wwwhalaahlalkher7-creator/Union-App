from pathlib import Path
root = Path(__file__).resolve().parents[1]
admin = (root / 'backend/src/admin.js').read_text(encoding='utf-8')
index = (root / 'backend/src/index.js').read_text(encoding='utf-8')
checks = {
    'admin Eino usage endpoint': "'/admin/security/eino-usage'" in index or '/admin/security/eino-usage' in index,
    'dashboard read permission': "requireAdminPermission(ctx, 'dashboard.read')" in admin or "requireAdminPermission(ctx, 'superadmin.read')" in admin,
    'legacy web admin absent': not (root / 'website/admin').exists(),
}
failed = [name for name, ok in checks.items() if not ok]
if failed: raise SystemExit('EINO DASHBOARD CHECK FAILED: ' + ', '.join(failed))
print('EINO DASHBOARD API CHECK PASSED')

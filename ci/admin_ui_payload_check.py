from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = (root / 'build.js').read_text(encoding='utf-8')
worker = (root / 'website/worker/index.js').read_text(encoding='utf-8')
checks = {
    'legacy web admin removed': not (root / 'website/admin').exists(),
    'build does not publish web admin': "name === 'admin'" in build and 'no web admin included' in build,
    'web admin route returns 404': "path === '/admin' || path.startsWith('/admin/')" in worker and 'status: 404' in worker,
    'TRINEX-Admin migration documented': 'TRINEX-Admin' in (root / 'README.md').read_text(encoding='utf-8'),
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit('TRINEX ADMIN MIGRATION CHECK FAILED: ' + ', '.join(failed))
print('TRINEX ADMIN MIGRATION CHECK PASSED: web admin absent and build/route guard active')

from pathlib import Path
root=Path(__file__).resolve().parents[1]
index=(root/'website/admin/index.html').read_text(); adapter=(root/'website/admin/js/api-adapter.js').read_text(); css=(root/'website/admin/css/admin.css').read_text()
checks={'adapter method':'getEinoUsage' in adapter,'admin endpoint':'/admin/security/eino-usage?hours=' in adapter,'dashboard card':'id="einoUsageCard"' in index,'success metric':'id="einoSuccess"' in index,'quota metric':'id="einoQuota"' in index,'provider error metric':'id="einoProviderErrors"' in index,'latency metric':'id="einoLatency"' in index,'limits':'einoStudentLimit' in index and 'einoGlobalLimit' in index,'loader wired':'loadEinoUsage()' in index,'dashboard styles':'Stage 8 — Eino governance dashboard' in css}
for k,v in checks.items(): print(('PASS' if v else 'FAIL'),k)
if not all(checks.values()): raise SystemExit(1)
print('EINO DASHBOARD CHECK PASSED')

from pathlib import Path

root = Path(__file__).resolve().parents[1]
adapter = (root / "website/admin/js/api-adapter.js").read_text()
content = (root / "website/admin/content.html").read_text()

checks = {
    "student create maps UI fields to API snake_case": "studentPayload(s)" in adapter and "student_number:studentNumber" in adapter and "department_id:departmentId" in adapter,
    "schedule maps semester to semester_id": "semester_id:p.semester_id||p.semesterId||p.semester||''" in adapter,
    "schedule maps department to department_id": "department_id:p.department_id||p.departmentId||p.department||''" in adapter,
    "schedule maps day/time fields": "day_of_week:p.day_of_week??p.dayOfWeek" in adapter and "start_time:p.start_time||p.startTime||''" in adapter,
    "notification options have Arabic labels": "{value:'general',label:'عام'}" in adapter and "{value:'urgent',label:'عاجل'}" in adapter,
    "select renderer supports value/label options": "typeof opt === 'object' ? opt.value : opt" in content,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    print("ADMIN UI PAYLOAD CHECK FAILED")
    for item in failed: print(" -", item)
    raise SystemExit(1)
print("ADMIN UI PAYLOAD CHECK PASSED")

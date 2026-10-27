from pathlib import Path

root = Path(__file__).resolve().parents[1]
users = (root / "apps/admin/lib/src/features/users/users_page.dart").read_text(encoding="utf-8")
academic = (root / "apps/admin/lib/src/features/academic/academic_page.dart").read_text(encoding="utf-8")
notifications = (root / "apps/admin/lib/src/features/notifications/notifications_page.dart").read_text(encoding="utf-8")
content = (root / "apps/admin/lib/src/features/content/content_page.dart").read_text(encoding="utf-8")
scanner = (root / "apps/admin/lib/src/features/imports/scanner_import_dialog.dart").read_text(encoding="utf-8")
checks = {
    "student records use API snake_case identifiers": all(k in users for k in ("student_number", "department_id", "current_semester_id")),
    "academic records use department/semester and schedule fields": all(k in academic for k in ("department_id", "semester_id", "day_of_week", "start_time", "end_time")),
    "notification targeting remains scoped by department and semester": all(k in notifications for k in ("target_department_id", "target_semester_id", "general", "academic")),
    "content publishing metadata remains wired": all(k in content for k in ("publish_at", "expires_at", "target_department_id", "target_semester_id")),
    "scanner review retains student and schedule import keys": all(k in scanner for k in ("studentNumber", "student_number", "startTime", "start_time", "semester_id", "department_id")),
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    print("ADMIN APP CONTRACT CHECK FAILED")
    for item in failed:
        print(" -", item)
    raise SystemExit(1)
print("ADMIN APP CONTRACT CHECK PASSED")

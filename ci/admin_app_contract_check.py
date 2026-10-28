from pathlib import Path

root = Path(__file__).resolve().parents[1]
users = (root / "apps/admin/lib/src/features/users/users_page.dart").read_text(encoding="utf-8")
academic = (root / "apps/admin/lib/src/features/academic/academic_page.dart").read_text(encoding="utf-8")
notifications = (root / "apps/admin/lib/src/features/notifications/notifications_page.dart").read_text(encoding="utf-8")
content = (root / "apps/admin/lib/src/features/content/content_page.dart").read_text(encoding="utf-8")
management = (root / "apps/admin/lib/src/features/management/management_page.dart").read_text(encoding="utf-8")
security = (root / "apps/admin/lib/src/features/security/security_page.dart").read_text(encoding="utf-8")
eino = (root / "apps/admin/lib/src/features/security/eino_monitor_page.dart").read_text(encoding="utf-8")
permissions = (root / "apps/admin/lib/src/admin_permissions.dart").read_text(encoding="utf-8")

checks = {
    "student records use API snake_case identifiers": all(k in users for k in ("student_number", "department_id", "current_semester_id")),
    "academic records use department/semester and schedule fields": all(k in academic for k in ("department_id", "semester_id", "day_of_week", "start_time", "end_time")),
    "Drive-backed PDFs use the supported upload contract": all(k in academic for k in ("/admin/drive/files", "subjectId", "base64", "'name': titleController.text.trim()")),
    "content events map to the real events resource": "_ContentKind.events => 'events'" in content and "_ContentKind.events => 'الفعاليات'" in content,
    "content publishing metadata remains wired": all(k in content for k in ("publish_at", "expires_at", "target_department_id", "target_semester_id")),
    "notification targeting remains scoped by department and semester": all(k in notifications for k in ("target_department_id", "target_semester_id", "general", "academic")),
    "marketplace records are manageable using supported CRUD": all(k in management for k in ("/admin/market-items", "title_ar", "description_ar", "contact_url")),
    "badges use supported create/edit/deactivate operations": all(k in management for k in ("/admin/badges", "rule_type", "rule_value")) and "لا يدعم حذفها نهائيًا" in management,
    "exam management uses supported endpoint actions": all(k in management for k in ("/admin/exams", "ensure-folder", "action': 'upload'", "action': 'rename'", "action': 'delete'")),
    "Eino monitoring uses the supported usage endpoint": "'/admin/security/eino-usage?hours=$_hours'" in eino,
    "security page only calls backend-supported audit endpoints": all(k in security for k in ("/admin/audit-logs?limit=100", "/admin/security/auth-events?limit=100")) and "/admin/imports" not in security,
    "moderator navigation exposes only supported moderation, notifications, and dashboard tools": all(k in permissions for k in ("static const moderator = 'moderator'", "AdminSection.feedbackReports", "AdminSection.notifications", "AdminSection.analytics", "AdminSection.eino")) and "AdminSection.students" not in permissions.split("case moderator:", 1)[1].split("default:", 1)[0],
    "unsupported import API is not referenced by the admin app": not any("/admin/imports" in p.read_text(encoding="utf-8") for p in (root / "apps/admin/lib").rglob("*.dart")),
}

failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(("PASS" if passed else "FAIL") + " " + name)
if failed:
    raise SystemExit("ADMIN APP CONTRACT CHECK FAILED: " + "; ".join(failed))
print("ADMIN APP CONTRACT CHECK PASSED")

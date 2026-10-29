from pathlib import Path

root = Path(__file__).resolve().parents[1]
users = (root / "apps/admin/lib/src/features/users/users_page.dart").read_text(encoding="utf-8")
academic = (root / "apps/admin/lib/src/features/academic/academic_page.dart").read_text(encoding="utf-8")
notifications = (root / "apps/admin/lib/src/features/notifications/notifications_page.dart").read_text(encoding="utf-8")
content = (root / "apps/admin/lib/src/features/content/content_page.dart").read_text(encoding="utf-8")
management = (root / "apps/admin/lib/src/features/marketplace/marketplace_exams_page.dart").read_text(encoding="utf-8")
security = (root / "apps/admin/lib/src/features/security/security_page.dart").read_text(encoding="utf-8")
eino = (root / "apps/admin/lib/src/features/security/eino_monitor_page.dart").read_text(encoding="utf-8")
permissions = (root / "apps/admin/lib/src/admin_permissions.dart").read_text(encoding="utf-8")
sections = (root / "apps/admin/lib/src/admin_section.dart").read_text(encoding="utf-8")
api = (root / "services/api/src/admin.js").read_text(encoding="utf-8")
academic_backend = (root / "services/api/src/academic.js").read_text(encoding="utf-8")
router = (root / "services/api/src/index.js").read_text(encoding="utf-8")
interactions = (root / "services/api/src/interactions.js").read_text(encoding="utf-8")
account = (root / "apps/admin/lib/src/features/account/account_page.dart").read_text(encoding="utf-8")
auth = (root / "services/api/src/auth.js").read_text(encoding="utf-8")

checks = {
    "student records use API snake_case identifiers": all(k in users for k in ("student_number", "department_id", "current_semester_id")),
    "academic records use department/semester and schedule fields": all(k in academic for k in ("department_id", "semester_id", "day_of_week", "start_time", "end_time")),
    "Drive-backed PDFs use the supported upload contract": all(k in academic for k in ("/admin/drive/files", "subjectId", "base64", "'name': titleController.text.trim()")),
    "content events map to the real events resource": "_ContentKind.events => 'events'" in content and "_ContentKind.events => 'الفعاليات'" in content,
    "content publishing metadata remains wired": all(k in content for k in ("publish_at", "expires_at", "target_department_id", "target_semester_id")),
    "notification targeting remains scoped by department and semester": all(k in notifications for k in ("target_department_id", "target_semester_id", "general", "academic")),
    "marketplace records are manageable using supported CRUD": all(k in management for k in ("/admin/market-items", "title_ar", "description_ar", "contact_url")),
    "badges are fixed backend definitions and not dashboard CRUD": "const BADGE_DEFINITIONS = Object.freeze([" in academic_backend and "const definitions = BADGE_DEFINITIONS" in academic_backend and "/admin/badges" not in management and "BADGE_ADMIN_DISABLED" in api,
    "exam management uses supported endpoint actions": all(k in management for k in ("/admin/exams", "ensure-folder", "action': 'upload'", "action': 'rename'", "action': 'delete'")),
    "Eino monitoring uses the supported usage endpoint": "'/admin/security/eino-usage?hours=$_hours'" in eino,
    "security page only calls backend-supported audit endpoints": all(k in security for k in ("/admin/audit-logs?limit=100", "/admin/security/auth-events?limit=100")) and "/admin/imports" not in security,
    "moderator navigation exposes only supported moderation, notifications, and dashboard tools": all(k in permissions for k in ("static const moderator = 'moderator'", "AdminSection.feedbackInbox", "AdminSection.notifications", "AdminSection.analytics", "AdminSection.eino")) and "AdminSection.students" not in permissions.split("case moderator:", 1)[1].split("default:", 1)[0],
    "market is a standalone navigation section and exams open from materials": "market('السوق'" in sections and "exams('إدارة الامتحانات'" in sections and "onOpenExams" in academic and "AdminSection.exams" in (root / "apps/admin/lib/src/shell.dart").read_text(encoding="utf-8"),
    "analytics are backed by the operational monitoring endpoint": "/admin/analytics/overview" in (root / "apps/admin/lib/src/features/analytics/analytics_page.dart").read_text(encoding="utf-8") and "adminAnalyticsOverview" in api and "path === '/admin/analytics/overview'" in router,
    "reports inbox and student submission are wired end to end": "adminModerationInbox" in api and "submitStudentFeedback" in api and "path === '/student/feedback'" in router and "/admin/moderation/inbox" in (root / "apps/admin/lib/src/features/moderation/feedback_reports_page.dart").read_text(encoding="utf-8"),
    "bulk selection is available while preserving row menu actions": all(k in academic for k in ("onLongPress: () => _startSelection(row)", "PopupMenuItem(value: 'select'", "_deleteSelected")) and all(k in content for k in ("onLongPress: () => _startSelection(item)", "_deleteSelected", "تحديد الكل")) and all(k in management for k in ("onLongPress: () => _startMarketSelection(item)", "_deleteSelectedMarket", "تحديد الكل")) and all(k in users for k in ("onLongPress:()=>_startStudentSelection(s)", "_deleteSelectedStudents", "تحديد الكل")),
    "moderator assignment and deletion authorization stay enforced by the API": all(k in api for k in ("adminSetStudentModerator", "is_moderator")) and "adminSetStudentModerator(ctx" in router and "export async function deleteReply" in interactions and "is_moderator" in interactions and "0035_student_moderators.sql" in {p.name for p in (root / "services/api/migrations").glob("*.sql")},
    "unsupported import API is not referenced by the admin app": not any("/admin/imports" in p.read_text(encoding="utf-8") for p in (root / "apps/admin/lib").rglob("*.dart")),
    "staff self-profile editing is backed by an authenticated API route": all(k in account for k in ("/auth/staff/profile", "displayName", "email", "onDisplayNameChanged")) and "staffUpdateProfile" in auth and "path === '/auth/staff/profile'" in router,
    "Cloudflare Worker consumption monitor is an optional real analytics integration": all(k in api for k in ("adminCloudflareWorkerMetrics", "CF_ANALYTICS_ACCOUNT_ID", "CF_ANALYTICS_API_TOKEN", "workersInvocationsAdaptive")) and "path === '/admin/analytics/cloudflare-worker'" in router and "cloudflare-worker?hours=$_hours" in (root / "apps/admin/lib/src/features/analytics/analytics_page.dart").read_text(encoding="utf-8"),
}

failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(("PASS" if passed else "FAIL") + " " + name)
if failed:
    raise SystemExit("ADMIN APP CONTRACT CHECK FAILED: " + "; ".join(failed))
print("ADMIN APP CONTRACT CHECK PASSED")

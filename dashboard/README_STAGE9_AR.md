# المرحلة 9 — لوحة التحكم عبر Association API

تم نقل حدود لوحة التحكم من Apps Script/Airtable إلى Association API على Cloudflare Workers.

## المصدر
- الأخبار والأنشطة والإنجازات: D1
- الطلاب: D1
- المواد والجداول: D1 + Google Drive للفهرسة الأكاديمية
- المستخدمون الإداريون: D1 + جلسات Staff Auth
- سجل العمليات: D1 `audit_logs`
- الإعلانات/الإشعارات: D1

## الدخول
تستخدم اللوحة:
`POST /api/v1/auth/staff/login`
ثم ترسل Bearer token مع الطلبات.

## الصلاحيات
- `super_admin`: كل شيء
- `content_manager`: المحتوى
- `academic_manager`: الطلاب/المواد/الجداول
- `moderator`: أدوات الإشراف

## مهم
لا توجد مفاتيح Google أو OmniRoute في ملفات Dashboard.
وحدات الإعلانات التجارية والنسخ الاحتياطي القديمة غير مفعلة.

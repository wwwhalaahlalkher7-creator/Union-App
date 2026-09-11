# المرحلة 9 — ترحيل Dashboard إلى Association API

## ما تم تنفيذه
1. إضافة migration `0007_dashboard_crud.sql`.
2. تفعيل CRUD الإداري لـ news/activities/achievements/announcements/subjects/materials/schedules/students/badges.
3. إضافة إدارة Staff Users مع PBKDF2 وعدم إعادة أي hash للمتصفح.
4. إضافة Audit Logs لكل إنشاء/تعديل/حذف/إرسال إشعار.
5. إضافة pagination بسيطة بحد أقصى 100 سجل للقراءة الإدارية.
6. ربط Dashboard مباشرة بـ `/api/v1` بدل Apps Script.
7. ربط دخول Dashboard بـ Staff Auth في Cloudflare Worker.
8. إيقاف الوحدات القديمة التي تعتمد على Apps Script التجاري/الإعلاني.
9. إبقاء Drive sync في Worker؛ لا توجد أسرار Google في الواجهة.

## ملاحظة Drive
المزامنة الحالية قراءة آمنة. عمليات رفع/نقل/إعادة تسمية Drive المباشرة لم تُفتح في المتصفح في هذه المرحلة حتى لا يتم توسيع صلاحيات Service Account بلا حاجة.

## قبل الإنتاج
- إنشاء D1 حقيقي وربطه في `wrangler.toml`.
- ضبط Secrets: `STAFF_BOOTSTRAP_TOKEN` وبيانات Google Drive وOmniRoute حسب الوحدات.
- ضبط `ALLOWED_ORIGINS` على نطاق الموقع/لوحة التحكم الحقيقي.
- تشغيل migrations 0001→0007.

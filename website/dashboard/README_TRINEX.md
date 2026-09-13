# TRINEX Dashboard — Backend Integration Pass 01

هذه النسخة هي لوحة التحكم المرتبطة مباشرة بـ TRINEX API على Cloudflare Worker.

## ما تم إصلاحه
- توحيد الهوية باسم TRINEX واستخدام أيقونة TRINEX المرفقة.
- ربط أدوار لوحة التحكم بمعرّفات الـ API الفعلية: `super_admin`, `content_manager`, `academic_manager`, `moderator`.
- إصلاح إرسال أدوار المستخدمين إلى `/admin/staff`.
- إصلاح عرض الأدوار في الواجهة.
- مزامنة حد كلمة المرور مع الـ backend: 8 أحرف.
- إزالة عمليات حذف سجل التدقيق غير المدعومة من الواجهة بدل إظهار أزرار ستفشل.
- الإبقاء على المحتوى الديناميكي عبر الـ API بدل البيانات الوهمية.

## API
`https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

## النشر
الـ GitHub workflow الموجود في المشروع يراقب `dashboard/**` ويقوم بالنشر تلقائيًا إلى Cloudflare Workers عند push إلى `main`.

# TRINEX — Google Apps Script

هذا المجلد هو النسخة المحفوظة من Google Apps Script المسؤول عن فهرسة Google Drive وحذف ملفات المواد عند طلب الحذف من لوحة التحكم.

> **مهم:** هذا المجلد جزء من المستودع للتوثيق والحفظ فقط، ولا يتم نشره إلى InfinityFree، ولا يدخل كملفات ثابتة ضمن موقع الويب. كما أن نشر Worker عبر Wrangler لا ينشر محتويات هذا المجلد كتطبيق Worker.

## إعداد Script Properties
- `ROOT_FOLDER_ID`: معرّف مجلد المواد الدراسية.
- `API_TOKEN`: نفس السر الموجود في Worker باسم `GOOGLE_APPS_SCRIPT_TOKEN`.
- `STATS_SHEET_ID`: اختياري، ينشأ تلقائيًا عند الحاجة.

## الحذف
عملية `deleteFiles` تستخدم Google Drive API عبر OAuth الخاص بحساب Apps Script للحذف النهائي للملفات المطلوبة. لا يتم حذف أي ملف من Worker مباشرة.

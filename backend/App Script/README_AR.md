# TRINEX — Google Apps Script

هذا المجلد هو النسخة المحفوظة من Google Apps Script المسؤول عن فهرسة Google Drive وحذف ملفات المواد عند طلب الحذف من لوحة التحكم.

> **مهم:** هذا المجلد جزء من المستودع للتوثيق والحفظ فقط، ولا يتم نشره إلى InfinityFree، ولا يدخل كملفات ثابتة ضمن موقع الويب. كما أن نشر Worker عبر Wrangler لا ينشر محتويات هذا المجلد كتطبيق Worker.

## إعداد Script Properties
- `ROOT_FOLDER_ID`: معرّف مجلد المواد الدراسية.
- `API_TOKEN`: نفس السر الموجود في Worker باسم `GOOGLE_APPS_SCRIPT_TOKEN`.
- `EMAIL_API_TOKEN`: نفس السر الموجود في Worker باسم `GOOGLE_APPS_SCRIPT_EMAIL_TOKEN`، ويستخدم فقط لإرسال أكواد استعادة كلمة المرور.
- `STATS_SHEET_ID`: اختياري، ينشأ تلقائيًا عند الحاجة.

## الحذف
عملية `deleteFiles` تستخدم Google Drive API عبر OAuth الخاص بحساب Apps Script للحذف النهائي للملفات المطلوبة. لا يتم حذف أي ملف من Worker مباشرة.

## اختبار صلاحية البريد
بعد نقل السكربت إلى `trinex.support@gmail.com` شغّل الدالة `testMailAppSetup` مرة واحدة من محرر Apps Script. هذه الدالة تتحقق من صلاحية `MailApp` وحصة الإرسال دون إرسال رسالة فعلية.

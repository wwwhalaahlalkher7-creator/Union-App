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


## نشر Web App الخاص باستعادة كلمة المرور

بعد أي تعديل على `Code.gs` يجب إنشاء **New deployment** أو تحديث deployment موجود ثم التأكد من أن `GOOGLE_APPS_SCRIPT_URL` في Worker يشير إلى رابط `/exec` الخاص بالـdeployment الحالي. يجب ضبط:

- Execute as: **Me**
- Who has access: **Anyone**
- لا تستخدم رابط `/dev` في الإنتاج.
- بعد النشر شغّل `testRecoveryEmail()` من حساب Apps Script للتأكد من أن MailApp يعمل والحصة اليومية متاحة.

إذا أعاد رابط `/exec` صفحة تسجيل دخول Google أو HTML لواجهة الصلاحيات بدل نتيجة `doPost`، فالمشكلة في إعدادات/صلاحيات الـdeployment وليست في Worker. الاستجابة الصحيحة للطلب تحتوي كائن JSON فيه `success: true` أو `success: false`؛ بالنسبة لمسار البريد يمكن أن يكون JSON داخل استجابة HTML الخاصة بـ`HtmlService`.

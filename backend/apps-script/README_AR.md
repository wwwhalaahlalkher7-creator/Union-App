# TRINEX — إعداد Google Apps Script

هذا المجلد هو طبقة الوصول إلى Google Drive. لا تحتاج إلى Google Service Account أو Private Key.

## 1) إنشاء مشروع Apps Script

أنشئ مشروعًا جديدًا في Google Apps Script، وانسخ محتوى `Code.gs` إليه.

## 2) Script properties

من **Project Settings → Script properties** أضف:

```text
ROOT_FOLDER_ID = معرّف مجلد المواد الدراسية
API_TOKEN      = سر طويل عشوائي
```

مثال لسر مناسب: قيمة عشوائية طويلة لا تشاركها مع المستخدمين.

## 3) النشر

اختر:

**Deploy → New deployment → Web app**

ثم:

- Execute as: **Me**
- Who has access: **Anyone**

انسخ رابط Web app.

## 4) ربط Cloudflare

في Worker:

```text
GOOGLE_APPS_SCRIPT_URL = رابط Web app
GOOGLE_APPS_SCRIPT_TOKEN = نفس قيمة API_TOKEN
```

الأول Variable عادي، والثاني Secret.

## 5) الاختبار

افتح رابط Web app مع:

```text
?action=index&token=YOUR_TOKEN
```

يجب أن يعود JSON يحتوي على:

```text
success: true
sections: [...]
files: [...]
```

بعد نجاح الاختبار، نفّذ مزامنة المواد من لوحة الإدارة عبر:

```text
POST /api/v1/admin/drive/sync
```

## ملاحظات

- `ROOT_FOLDER_ID` يبقى داخل Script properties ولا يدخل Git.
- لا تضع `API_TOKEN` في `wrangler.toml` أو Flutter.
- Flutter والموقع لا يتصلان بـApps Script مباشرة.
- Apps Script يستخدم `DriveApp` فقط، فلا يحتاج كود OAuth Service Account في Worker.
- توجد حصص تشغيل لـ Apps Script؛ لذلك Worker/D1 هما طبقة التخزين والتقديم، وليس Apps Script نقطة خدمة لكل طالب.

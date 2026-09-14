# المرحلة 6 — Google Drive عبر Google Apps Script

تم استبدال اتصال Google Drive المباشر من Cloudflare Worker بحاجز Google Apps Script.
الـWorker يبقى الواجهة الوحيدة للتطبيق والموقع، بينما Apps Script يملك صلاحية قراءة Drive.

## البنية

```text
Google Drive → Google Apps Script → Cloudflare Worker → D1 → Flutter/Web
```

## إعداد Google Apps Script

الملف الجاهز موجود في `backend/apps-script/Code.gs`.

من Project Settings → Script properties أضف:

```text
ROOT_FOLDER_ID = معرّف مجلد المواد الدراسية
API_TOKEN      = سر عشوائي طويل
```

ثم Deploy → New deployment → Web app:
- Execute as: Me
- Who has access: Anyone

احتفظ برابط Web app.

## إعداد Cloudflare Worker

المتغير العام:

```text
GOOGLE_APPS_SCRIPT_URL
```

والسر:

```text
GOOGLE_APPS_SCRIPT_TOKEN
```

قيمة `GOOGLE_APPS_SCRIPT_TOKEN` يجب أن تساوي `API_TOKEN` في Apps Script.

لا يحتاج Worker إلى:

```text
GOOGLE_SERVICE_ACCOUNT_EMAIL
GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY
GOOGLE_DRIVE_ROOT_FOLDER_ID
```

## المزامنة

`POST /api/v1/admin/drive/sync`

يتطلب جلسة موظف بصلاحية `Super Admin` أو `Academic Manager`.

يمكن فرض إعادة قراءة Drive بدل كاش Apps Script عبر: `?nocache=1`.

## قواعد الأمان

- Flutter والموقع لا يتصلان بـApps Script مباشرة.
- رابط Apps Script يمكن أن يكون عامًا، لكن البيانات محمية بـ`API_TOKEN`.
- الـWorker هو نقطة API الوحيدة للتطبيق.
- لا توجد Service Account private keys في Cloudflare أو Git.
- Apps Script يستخدم `DriveApp` بدل Advanced Drive API، لتقليل الاعتماد على Google Cloud.

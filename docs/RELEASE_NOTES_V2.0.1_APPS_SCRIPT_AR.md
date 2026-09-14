# TRINEX V2.0.1 — Google Apps Script Drive Adapter

## ما تم تنفيذه

- إزالة اتصال Google Drive المباشر من Cloudflare Worker.
- إزالة JWT/OAuth Service Account من طبقة Worker.
- إضافة `backend/apps-script/Code.gs` كطبقة Drive Adapter.
- نقل `ROOT_FOLDER_ID` إلى Script properties داخل Apps Script.
- إضافة `API_TOKEN` لحماية Web App.
- إضافة `GOOGLE_APPS_SCRIPT_URL` كمتغير Worker.
- إضافة `GOOGLE_APPS_SCRIPT_TOKEN` كسر Worker.
- الحفاظ على API الإداري الحالي: `POST /api/v1/admin/drive/sync`.
- الحفاظ على D1 كمصدر تقديم موحد للتطبيق والموقع.
- دعم البحث التكراري داخل مجلدات السمستر والمواد.
- الحفاظ على بيانات PDF الأساسية والروابط وpinning والتاريخ والحجم.

## الأسرار القديمة التي لم تعد مطلوبة

```text
GOOGLE_SERVICE_ACCOUNT_EMAIL
GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY
GOOGLE_DRIVE_ROOT_FOLDER_ID
```

## الأسرار الجديدة

Apps Script:

```text
ROOT_FOLDER_ID
API_TOKEN
```

Cloudflare:

```text
GOOGLE_APPS_SCRIPT_TOKEN
```

ومتغير غير سري:

```text
GOOGLE_APPS_SCRIPT_URL
```

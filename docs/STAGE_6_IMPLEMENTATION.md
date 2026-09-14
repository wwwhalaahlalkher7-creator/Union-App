# Stage 6 — Google Drive Adapter Migration

تمت إعادة تصميم طبقة Drive لتكون: Google Drive → Google Apps Script → Cloudflare Worker → D1.

## لماذا؟

يتم التخلص من OAuth Service Account/JWT داخل Worker ومن الأسرار الثلاثة المرتبطة به، مع إبقاء Worker هو الـAPI الموحد.

## الأسرار الجديدة

### Apps Script — Script properties
- `ROOT_FOLDER_ID`
- `API_TOKEN`

### Cloudflare Worker
- `GOOGLE_APPS_SCRIPT_URL` (var)
- `GOOGLE_APPS_SCRIPT_TOKEN` (secret)

## الأسرار التي لم تعد مطلوبة

- `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`
- `GOOGLE_DRIVE_ROOT_FOLDER_ID`

## المزامنة

`POST /api/v1/admin/drive/sync`

الـWorker يجلب فهرسًا مسطحًا من Apps Script، يطابق القسم والفصل مع D1، وينشئ/يحدّث subjects وmaterials.

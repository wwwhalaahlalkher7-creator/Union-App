# المرحلة 6 — فهرس Google Drive

هذه النسخة تضيف مزامنة Google Drive إلى D1.

### أسرار Cloudflare المطلوبة

```text
GOOGLE_SERVICE_ACCOUNT_EMAIL
GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY
GOOGLE_DRIVE_ROOT_FOLDER_ID
```

لا تضع أيًا منها في `wrangler.toml` أو Git.

### المزامنة

بعد تسجيل دخول حساب إدارة بصلاحية Super Admin أو Academic Manager:

```http
POST /api/v1/admin/drive/sync
```

ولعرض آخر عمليات المزامنة:

```http
GET /api/v1/admin/drive/sync-status
```

### ملاحظة

المشروع لا يفترض أن معرف مجلد Drive الموجود في Apps Script ما زال هو المعرف الإنتاجي؛ يتم تمريره كـ Secret حتى يمكن تغييره بدون تعديل الكود.

# TRINEX Website

الموقع العام ولوحة الإدارة. كلاهما يتعاملان مع البيانات عبر TRINEX API.

## URLs

- Public site: `https://ush-eng.great-site.net/`
- Admin: `https://ush-eng.great-site.net/admin/`
- API: `https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

## Structure

```text
website/
├── public pages + assets
├── worker/                 Worker/static security boundary للموقع
└── admin/
    ├── HTML pages
    ├── js/ + css/
    └── worker/             boundary لمسار /admin
```

`website/admin/` هو المصدر الوحيد للوحة الإدارة؛ لا يوجد `dashboard/` source tree.

## Data flow

```text
Public Website ─┐
Admin Dashboard ├──> TRINEX API ──> D1 / R2 / Drive adapter
Flutter App ────┘
```

لا تعيد تكاملات Apps Script/Airtable القديمة إلى صفحات الموقع. Google Apps Script مستخدم فقط كـadapter للوصول إلى Google Drive.

## Deployment

`npm run build` ينشئ `dist/` من `website/` و`website/admin/`.

النشر الحالي يتم من `.github/workflows/ci.yml` بعد بناء `dist/`، ثم رفع محتوياته عبر FTPS إلى الاستضافة الإنتاجية. ملفات Worker الموجودة داخل `website/` و`website/admin/` هي حدود استضافة Cloudflare الحالية/البديلة ولا تدخل حزمة الموقع المنشورة بواسطة `build.js`.

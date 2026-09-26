# TRINEX Website

الموقع العام ولوحة الإدارة.

## URLs

- Public site: `https://ush-eng.great-site.net/`
- Admin: `https://ush-eng.great-site.net/admin/`
- API: `https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

## Structure

```text
website/
├── public pages + assets
├── worker/                 Worker/static security boundary للموقع
└── dashboard/
    ├── HTML pages
    ├── js/ + css/
    └── worker/             boundary لمسار /admin
```

## Data flow

الموقع واللوحة يقرآن ويعدلان البيانات عبر TRINEX API. لا تعيد تكاملات Apps Script/Airtable القديمة إلى صفحات الموقع.

## Deployment

النشر الحالي موثق في `../docs/DEPLOYMENT.md` ويُدار عبر `.github/workflows/deploy.yml` ضمن job باسم `website-deploy`. ملفات Cloudflare Worker الموجودة هنا تمثل مسار الاستضافة البديل/المستقبلي ولا تدخل في حزمة FTPS الحالية.

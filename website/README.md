# TRINEX Website

الموقع العام ولوحة الإدارة.

## URLs

- Public site: `https://ush-eng.great-site.net/`
- Dashboard: `https://ush-eng.great-site.net/admin/`
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

النشر الآلي موثق في `../docs/DEPLOYMENT.md` ويُدار عبر `.github/workflows/deploy-website.yml`.

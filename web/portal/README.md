# TRINEX Website

الموقع العام فقط. الإدارة تتم حصريًا من تطبيق Flutter المستقل `TRINEX-Admin` عبر TRINEX API.

## URLs
- Public site: `https://ush-eng.great-site.net/`
- API: `https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`
- Admin: لا توجد لوحة إدارة ويب؛ استخدم تطبيق TRINEX-Admin.

## Structure
```text
web/portal/
├── public pages + assets
└── worker/                 Worker/static security boundary للموقع العام
```

## Data flow
```text
Public Website ─┐
TRINEX-Admin ────┴──> TRINEX API ──> D1 / R2 / Drive adapter
```

`npm run build` ينشئ `dist/` من ملفات الموقع العامة فقط. مسار `/admin` غير منشور؛ الإدارة تتم من تطبيق Flutter الأصلي داخل `apps/admin/`.
النشر عبر GitHub Actions إلى استضافة الموقع، دون تغيير نشر الـAPI أو إعداداته.

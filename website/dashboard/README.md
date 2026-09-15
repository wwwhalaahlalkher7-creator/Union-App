# TRINEX Admin Dashboard

لوحة الإدارة التي تعمل تحت `/admin/` وتتصل بـTRINEX API.

## الصفحات الحالية

- Dashboard overview
- Content
- Materials
- Schedule
- Students
- Users / Staff
- Moderation
- Security
- Settings
- Account

## Authentication

الدخول يتم عبر Staff Auth في API. session الخاصة باللوحة مؤقتة وتُحفظ في `sessionStorage`.

## Configuration

عنوان API العام موجود في `config.js` لأنه غير سري. لا تضع tokens أو API keys في هذا الملف.

## Development

ملفات JavaScript يجب أن تمر:

```bash
node --check website/dashboard/js/api-adapter.js
python3 ci/web_security_check.py
python3 ci/xss_dom_check.py
```

## Deployment

لا تنشر `worker/` أو `wrangler.toml` كملفات موقع ثابت إلى InfinityFree؛ workflow هو الذي يبني الحزمة الصحيحة. راجع `docs/DEPLOYMENT.md`.

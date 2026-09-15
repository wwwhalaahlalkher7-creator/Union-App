# Security Baseline

## Authentication

- Student وStaff sessions لها lifecycle مستقل.
- Refresh token rotation محمي من إعادة الاستخدام.
- توجد rate limits لمحاولات auth.
- IP لا يُحفظ خامًا في آلية hardening؛ يستخدم hash عند الحاجة التشغيلية.
- صلاحيات الإدارة مركزية في Worker.

## Dashboard

- جلسة لوحة الإدارة محفوظة في `sessionStorage` وليس `localStorage`.
- CSP وsecurity headers مفعلة.
- CRUD يستخدم projections صريحة بدل `SELECT *` للبيانات الحساسة.
- حذف المحتوى يعتمد archive lifecycle، بينما الموارد التشغيلية تستخدم soft-delete.

## Eino

- لا تحفظ prompts أو responses في telemetry.
- توجد حدود burst وحدود يومية للطالب والزائر والحد العالمي.
- OmniRoute مسؤول عن provider routing/fallback/cost controls.
- `OMNIROUTE_API_KEY` لا يصل إلى Flutter.

## Data handling

لا تضع في Git:

- كلمات مرور الطلاب.
- access/refresh tokens.
- API keys.
- Android keystore.
- exports حقيقية للطلاب.
- Google Script tokens.

## مراجعة قبل الدمج

شغّل:

```bash
python3 ci/auth_hardening_check.py
python3 ci/web_security_check.py
python3 ci/xss_dom_check.py
python3 ci/admin_crud_check.py
python3 ci/flutter_secure_storage_check.py
```

إذا فشل أحدها، لا تتجاوزه لمجرد نجاح build.

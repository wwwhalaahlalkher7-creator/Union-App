# Troubleshooting

## 1. API يرجع 503

ابدأ بـ:

```text
GET /api/v1/health?deep=true
```

فرّق بين:

- D1 غير متصل → راجع binding/database/migrations.
- Eino/OmniRoute غير متاح → راجع `OMNIROUTE_BASE_URL` و`OMNIROUTE_API_KEY` وحالة OmniRoute.
- Drive غير مهيأ → راجع `GOOGLE_APPS_SCRIPT_URL` و`GOOGLE_APPS_SCRIPT_TOKEN`.

لا تغيّر Flutter قبل تحديد الطبقة الفاشلة.

## 2. Eino يرجع 502/503

افحص أولًا:

1. `OMNIROUTE_BASE_URL` بدون `/chat/completions`.
2. يمكن أن يحتوي العنوان على `/v1`، والكود يتعامل مع ذلك.
3. `OMNIROUTE_API_KEY` صحيح داخل GitHub/Cloudflare Secrets.
4. `EINO_MODEL=auto` أو قيمة `provider/model` صحيحة.
5. راقب telemetry من لوحة الإدارة.

## 3. Flutter لا يمر CI

شغّل محليًا:

```bash
cd flutter
flutter pub get
flutter analyze
flutter test
```

إذا كان الفشل في version metadata، افحص `flutter/VERSION` ثم شغّل `tool/sync_version.py`.

## 4. D1 migration تفشل

لا تعدّل migration قديمة. افحص:

```bash
cd backend
npm run migrate:local
```

ثم راجع آخر migration فقط، وعلاقات foreign keys وترتيب الملفات الرقمي.

## 5. Dashboard لا يسجل الدخول

تحقق من:

- `POST /api/v1/auth/staff/login`.
- صحة `user_id` وكلمة المرور.
- صلاحية session.
- أن المتصفح يستخدم `/admin/` الصحيح.
- أن API base URL في `website/dashboard/config.js` صحيح.

## 6. الموقع لا يعرض المحتوى

تحقق من:

- API health.
- endpoint public المطلوب.
- CORS للمتصفح.
- حالة D1.
- عدم وجود dependency قديمة على Apps Script/Airtable.

## قاعدة التشخيص

ابدأ من الأسفل إلى الأعلى:

```text
Provider / Drive → Worker → API contract → Dashboard/Flutter → UI
```

لا تعالج UI symptom إذا كانت البيانات لا تصل أصلًا.

# Troubleshooting

## 1. API يرجع 503

ابدأ بـ:

```text
GET /api/v1/health?deep=true
```

فرّق بين:

- D1 غير متصل → راجع binding/database/migrations.
- Eino/Free.ai غير متاح → راجع `FREE_AI_BASE_URL` و`FREE_AI_API_KEY` وحالة Free.ai.
- Drive غير مهيأ → راجع `GOOGLE_APPS_SCRIPT_URL` و`GOOGLE_APPS_SCRIPT_TOKEN`.

لا تغيّر Flutter قبل تحديد الطبقة الفاشلة.

## 2. Eino يرجع 502/503

افحص أولًا:

1. `FREE_AI_BASE_URL` مضبوط على `https://api.free.ai/v1` (ولا تضف `/chat/completions` في المتغير).
2. يمكن أن يحتوي العنوان على `/v1`، والكود يتعامل مع ذلك.
3. `FREE_AI_API_KEY` صحيح داخل GitHub/Cloudflare Secrets.
4. `OMNIROUTE_API_KEY` هو مفتاح Gateway من OmniRoute → API Keys، وليس مفتاح Mistral/المزود نفسه.
5. `EINO_MODEL=auto` هو الوضع الافتراضي؛ وإذا رفضت نسخة OmniRoute الحالية alias `auto` يحاول Adapter اختيار نموذج محادثة صالح من `/v1/models`.
6. راقب telemetry من لوحة الإدارة، وتحقق من `/v1/models` في OmniRoute قبل فحص Flutter.

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
- أن API base URL في `website/admin/config.js` صحيح.

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

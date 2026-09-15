# المعمارية الحالية

## 1. الصورة الكبيرة

```text
Flutter Android ───────┐
                       │
Website ───────────────┼──> Cloudflare Worker API v1 ──> D1
Dashboard ─────────────┘              │
                                      ├──> Google Apps Script → Google Drive
                                      └──> Leo-OmniRoute → Eino providers
```

### القواعد الأساسية

1. **TRINEX API هو بوابة التشغيل** للتطبيق والموقع ولوحة الإدارة.
2. **D1 هو مخزن البيانات التشغيلي** للمحتوى والحسابات والسجلات والعدادات.
3. Google Apps Script ليس API للتطبيق؛ دوره الحالي هو adapter محدود لفهرسة Google Drive.
4. Eino لا يحمل أسرار المزود داخل Flutter؛ الطلب يمر عبر Worker ثم OmniRoute.
5. لوحة الإدارة تغيّر البيانات عبر API، وليس عبر اتصال مباشر بقاعدة D1 من المتصفح.

## 2. Flutter

```text
lib/
├── app/                    router + app shell
├── core/                   config, network, storage, theme, update
├── data/
│   ├── models/             DTO/domain models
│   └── repositories/       API-facing repositories
├── features/               screens by feature
└── shared/widgets/          reusable UI components
```

القاعدة: الشاشة لا تبني HTTP requests بنفسها. استخدم repository ثم `ApiClient`/`AuthenticatedClient`.

## 3. Backend

`backend/src/index.js` هو Worker entry point الحالي. داخله توجد حدود واضحة نسبيًا:

- public/version/health
- authentication + sessions
- student services
- content/materials/schedule
- progress/XP/badges
- comments/reactions
- admin permissions + CRUD + audit
- Eino gateway + quota + telemetry
- Drive synchronization adapter

قاعدة الصيانة: عند إضافة نطاق كبير جديد، أنشئ module مستقلًا بدل زيادة حجم `index.js` أكثر. نقل الكود إلى modules يجب أن يكون تدريجيًا مع إبقاء API contract ثابتًا.

## 4. D1

المigrations في `backend/migrations/` مرتبة رقميًا. كل migration مطبقة على الإنتاج تعتبر تاريخًا دائمًا.

**ممنوع:** تعديل أو حذف migration قديمة بعد تطبيقها على الإنتاج.

**المسموح:** إضافة `0019_...sql` ثم تشغيلها عبر pipeline.

## 5. Website + Dashboard

- `website/` = public site.
- `website/dashboard/` = admin UI.
- كلاهما يستخدمان TRINEX API.
- `website/dashboard/worker/` مسؤول عن حماية مسار `/admin` عند نشر Worker الخاص باللوحة.

## 6. CI/CD

GitHub Actions تقسم التحقق إلى:

- Flutter analyze/test/build.
- Backend syntax + migrations + security contracts.
- Website JavaScript/security/package/deploy.

الهدف من `ci/*.py` ليس اختبار كل سطر، بل حماية invariants حرجة تمنع رجوع أخطاء سبق إصلاحها.

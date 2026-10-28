# المعمارية الحالية

## 1. الصورة الكبيرة

```text
Flutter Android ───────┐
                       │
Website ───────────────┼──> Cloudflare Worker API v1 ──> D1
Dashboard ─────────────┘              │
                                      ├──> TRINEX Drive (Google Apps Script) → Google Drive
                                      ├──> TRINEX Gmail (Google Apps Script) → Gmail
                                      └──> Mistral → Groq → Free.ai (capability fallbacks)
```

### القواعد الأساسية

1. **TRINEX API هو بوابة التشغيل** للتطبيق والموقع ولوحة الإدارة.
2. **D1 هو مخزن البيانات التشغيلي** للمحتوى والحسابات والسجلات والعدادات.
3. Google Apps Script ليس API للتطبيق؛ دوره الحالي هو adapter محدود لفهرسة Google Drive.
4. Eino لا يحمل أسرار المزود داخل Flutter؛ الطلب يمر عبر Worker ثم طبقة توجيه capability-first التي تختار Mistral/Groq/Free.ai حسب القدرة والأخطاء القابلة لإعادة المحاولة.
5. لوحة الإدارة تغيّر البيانات عبر API، وليس عبر اتصال مباشر بقاعدة D1 من المتصفح.

## 2. Flutter

```text
apps/
├── student/                تطبيق الطلاب (Flutter)
│   ├── lib/                الشاشات وطبقات البيانات المشتركة للطلاب
│   ├── test/               اختبارات الطلاب
│   └── VERSION             مصدر إصدار الطلاب الوحيد
└── admin/                  تطبيق الإدارة (Flutter Android + Windows)
    ├── lib/src/            صفحات الإدارة وعميل API والصلاحيات
    ├── test/               اختبارات الإدارة
    └── pubspec.yaml        إصدار الإدارة وتبعياتها
```

لكل تطبيق اعتمادياته واختباراته وإصداره المستقل. يتصل كل منهما بالـBackend عبر API، ولا يتصل مباشرةً بقاعدة D1.

## 3. Backend

`services/api/src/index.js` هو **Worker entry point + HTTP router فقط**. منطق المجال مفصول حسب المسؤولية:

```text
src/index.js
├── core.js          response, parsing, DB/query, crypto, shared limits
├── auth.js          student/staff sessions and authentication
├── public.js        public content, settings and public materials
├── student.js       student profile, notifications and devices
├── academic.js      semesters, subjects, materials, schedule, progress, XP, badges
├── interactions.js  comments, replies and reactions
├── media.js         R2 media upload/read/ownership/quota
├── admin.js         permissions, CRUD, moderation, audit and admin settings
├── eino.js          Eino gateway, memory, media, quota and telemetry
└── drive.js         Google Drive synchronization adapter
```

قاعدة الصيانة: أضف المسار إلى `index.js`، وضع منطق التنفيذ في module مالك للنطاق. الوحدات لا تتعامل مع HTTP routing مباشرة؛ تستقبل `ctx` موحدًا وتعيد `Response` عبر helpers الموجودة في `core.js`. لا تعيد دمج domain logic داخل `index.js`.

## 4. D1

المigrations في `services/api/migrations/` مرتبة رقميًا. كل migration مطبقة على الإنتاج تعتبر تاريخًا دائمًا.

**ممنوع:** تعديل أو حذف migration قديمة بعد تطبيقها على الإنتاج.

**المسموح:** إضافة `0019_...sql` ثم تشغيلها عبر pipeline.

## 5. Website + Native Admin

- `web/portal/` = الموقع العام وStatic Worker.
- `apps/admin/` = تطبيق الإدارة الأصلي المبني بـFlutter (Android وWindows).
- تطبيق الطلاب وتطبيق الإدارة والموقع العام تتصل جميعها بـTRINEX API.
- المسار `/admin/` غير منشور على الموقع العام؛ Worker يرجع 404 له، ولا يعتمد تطبيق الإدارة على لوحة ويب.

## 6. CI/CD

GitHub Actions تقسم التحقق إلى:

- Flutter analyze/test/build.
- Backend syntax + migrations + security contracts.
- Website JavaScript/security/package/deploy.

الهدف من `ci/*.py` ليس اختبار كل سطر، بل حماية invariants حرجة تمنع رجوع أخطاء سبق إصلاحها.

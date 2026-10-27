# TRINEX Monorepo

المستودع الموحد لمنصة TRINEX: تطبيق الطلاب، تطبيق الإدارة، الـBackend، والموقع العام. بدأ هذا المستودع بتاريخ Git جديد كما تقرر؛ لا يحتوي على تاريخ المستودعات السابقة.

## الإصدارات المعتمدة

- **تطبيق الطلاب:** `2.0.3+2`، الإصدار العام `v2.0.3`. المصدر المعتمد: `apps/student/VERSION`.
- **تطبيق الإدارة:** `1.1.0+1`، الإصدار العام `v1.1.0`. المصدر الحالي: `apps/admin/pubspec.yaml`.
- **Backend API:** `v1`؛ لم يتغير عقد API بسبب نقل المستودع.

## بنية المستودع

```text
TRINEX/
├── apps/
│   ├── student/       # Flutter student app
│   └── admin/         # Flutter administration app (Android + Windows)
├── services/
│   └── api/           # Cloudflare Worker + D1 migrations
├── web/
│   └── portal/        # Public website + static asset Worker
├── ci/                # Existing cross-project integrity/security checks
├── docs/              # Platform and release documentation
├── .github/workflows/ # Central CI/CD workflows
├── build.js           # Website distribution builder
└── package.json       # Root web/portal/tooling scripts
```

## مبادئ تنظيم المستودع

1. لكل تطبيق Flutter تبعياته واختباراته وإصداره المستقل.
2. النشر إلى Cloudflare Worker والموقع لا يُفترض أن يحدث عند تغيير تطبيق الإدارة فقط.
3. تغيير API أو migrations يجب أن يكون متوافقًا مع العملاء؛ اختبارات العقود موجودة في `ci/`.
4. أسرار الإنتاج ومفاتيح Android تبقى في GitHub Secrets / Cloudflare Secrets ولا توضع في الملفات.
5. لا تُعدّل migrations مطبّقة على الإنتاج؛ أضف migration جديدة.
6. لم يتم نقل تاريخ Git القديم عمدًا. هذا مجلد عمل ببداية تاريخ جديدة؛ يجب ربطه بمستودع GitHub جديد أو استبدال محتويات المستودع المقصود بعد أخذ نسخة احتياطية.

## تشغيل تطبيق الطلاب

```bash
cd apps/student
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

الإصدار الرسمي لتطبيق الطلاب يقرأ من `apps/student/VERSION`. بعد تعديل القيمة، شغّل:

```bash
python3 tool/sync_version.py
```

## تشغيل تطبيق الإدارة

```bash
cd apps/admin
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
flutter build windows --release  # Windows host
```

إصدار التطبيق مضبوط حاليًا في `apps/admin/pubspec.yaml` كـ `1.1.0+1`.

## Backend

```bash
cd services/api
npm install --no-audit --no-fund
npm run check
npm run migrate:local
```

لا تنفذ `migrate:remote` إلا بعد مراجعة التغييرات والتأكد من بيئة الإنتاج.

## Website

من جذر المستودع:

```bash
npm ci --ignore-scripts --no-audit --no-fund
npm run build
```

ينتج البناء ملفات التوزيع داخل `dist/`، ولا تُحفظ ملفات `dist/` في Git.

## فحوصات المشروع

من جذر المستودع، يمكن تشغيل فحوصات سلامة المشروع والعقود:

```bash
python3 ci/verify_project.py
python3 ci/workflow_consistency_check.py
python3 ci/version_consistency_check.py
python3 ci/admin_version_check.py
python3 ci/backend_api_contract_check.py
python3 ci/web_security_check.py
```

## GitHub Actions

- `ci.yml`: فحوصات الطلاب وBackend والويب. تغييرات كل مكوّن تُحدد قبل تشغيل خطوات النشر لتجنب نشر API أو الموقع بسبب تغيير تطبيق الإدارة وحده.
- `admin-ci.yml`: تحليل واختبارات تطبيق الإدارة، وبناء APK وWindows.
- `release.yml`: إصدار تطبيق الطلاب عند تأكيد الإصدار يدويًا.

قبل تفعيل النشر في مستودع جديد، أعد إعداد GitHub Secrets / Variables المطلوبة في `docs/CONFIGURATION.md` وراجع `docs/DEPLOYMENT.md`. لم يتم تنفيذ نشر فعلي أو الاتصال بخدمات الإنتاج خلال إعداد هذا المستودع.

## مستندات أساسية

- `docs/ARCHITECTURE.md` — معمارية النظام.
- `docs/CONFIGURATION.md` — متغيرات الإعداد والأسرار.
- `docs/DEVELOPMENT.md` — التطوير المحلي.
- `docs/DEPLOYMENT.md` — النشر.
- `docs/RELEASE.md` — إصدار تطبيق الطلاب.
- `apps/admin/docs/ARCHITECTURE.md` — معمارية تطبيق الإدارة.
- `docs/MONOREPO_MIGRATION.md` — ما تغيّر عند إنشاء المستودع الموحد.

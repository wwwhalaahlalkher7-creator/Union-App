# TRINEX — منصة رابطة كلية الهندسة والعمارة

منصة متعددة الواجهات تتكوّن من تطبيق Android بـ Flutter، وواجهة ويب عامة، ولوحة تحكم إدارية، وواجهة API موحّدة على Cloudflare Workers مع D1.

> **هدف هذا الملف:** يكون نقطة البداية الوحيدة لأي مطوّر أو مسؤول صيانة جديد. تفاصيل التنفيذ التاريخية لم تعد تُحفظ كـ README لكل مرحلة؛ Git history يحتفظ بالتاريخ، بينما مجلد `docs/` يصف الحالة التشغيلية الحالية فقط.

## المكوّنات

```text
TRINEX
├── flutter/                 تطبيق Android (Flutter)
├── backend/                 API + D1 + Eino gateway + Drive adapter
├── website/                 الموقع العام + لوحة الإدارة
├── ci/                      فحوصات العقود والأمان والإصدار
├── docs/                    الوثائق التشغيلية الحالية
└── .github/workflows/       CI/CD
```

## Source of Truth

| المجال | المصدر |
|---|---|
| إصدار التطبيق | `flutter/VERSION` |
| منطق Flutter | `flutter/lib/` |
| API | `backend/src/index.js` |
| مخطط D1 والتغييرات | `backend/migrations/` |
| إعداد Worker | `backend/wrangler.toml` |
| الموقع العام | `website/` |
| لوحة الإدارة | `website/dashboard/` |
| فحوصات الجودة | `ci/` |
| أسرار الإنتاج | GitHub Actions / Cloudflare Secrets فقط |

## البنية التشغيلية

```text
Android Flutter ─┐
                 ├──> TRINEX API (Cloudflare Worker) ──> D1
Public Website ──┤                                  ├──> Google Drive adapter
Dashboard ──────┘                                  └──> Leo-OmniRoute → Eino providers
```

المسار العام للتطبيق والموقع هو **TRINEX API**. Google Apps Script موجود حاليًا فقط كـ **adapter للوصول إلى Google Drive**، وليس كـ API تشغيلي مباشر للتطبيق أو الموقع.

## الحالة الحالية

- Flutter version: `2.0.0+1` من `flutter/VERSION`.
- Backend API: `v1`.
- Android Application ID: `com.leoassociation.app`.
- Eino يمر عبر TRINEX API إلى OmniRoute؛ مفاتيح المزود لا تدخل التطبيق.
- الإعلانات التجارية القديمة غير مفعلة.
- Student authentication اختياري لبدء التطبيق، بينما الخدمات الدراسية المحمية تتطلب جلسة صالحة.

## بدء الصيانة

1. اقرأ `docs/ARCHITECTURE.md` لفهم الحدود بين المكوّنات.
2. اقرأ `docs/CONFIGURATION.md` قبل لمس أي secret أو متغير إنتاج.
3. اقرأ `docs/DEVELOPMENT.md` للأوامر والفحوصات.
4. عند الإصدار، اتبع `docs/RELEASE.md` فقط.
5. عند عطل إنتاجي، ابدأ من `docs/TROUBLESHOOTING.md`.

## أهم أوامر التحقق

### Flutter

```bash
cd flutter
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

### Backend

```bash
cd backend
npm install --no-audit --no-fund
node --check src/index.js
npm run migrate:local
```

### عقود المشروع

```bash
python3 ci/verify_project.py
python3 ci/release_check.py
python3 ci/final_release_check.py
python3 ci/admin_crud_check.py
python3 ci/auth_hardening_check.py
python3 ci/eino_dashboard_check.py
python3 ci/web_security_check.py
python3 ci/xss_dom_check.py
python3 ci/flutter_secure_storage_check.py
```

## النشر

النشر المعتاد يتم عبر GitHub Actions عند الدفع إلى `main`، مع أسرار الإنتاج داخل GitHub Secrets. لا تُرفع ملفات `.env` أو مفاتيح Android أو مفاتيح OmniRoute إلى Git.

للتفاصيل: `docs/DEPLOYMENT.md`.

## سياسة التغيير

- لا تعدّل نفس المعلومة في أكثر من مصدر للحقيقة.
- لا تضع بيانات تشغيلية ثابتة داخل Flutter أو الموقع إذا كان مكانها الطبيعي D1/Dashboard.
- لا تضف endpoint جديدًا دون تحديث عقد API والاختبارات المناسبة.
- لا تغيّر `applicationId` أو مفتاح توقيع الإنتاج أثناء إصدار تحديث.
- لا تحذف migration مطبقة على الإنتاج؛ أضف migration جديدة.
- احذف الوثائق المرحلية القديمة بدل إعادة استخدامها كمرجع للحالة الحالية.

## الترخيص والبيانات

هذا المستودع مخصص لمشروع TRINEX. لا تضع فيه بيانات طلاب حقيقية، كلمات مرور، مفاتيح API، ملفات keystore، أو exports حساسة.

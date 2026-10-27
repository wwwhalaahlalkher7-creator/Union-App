# TRINEX Admin

إصدار التطبيق في هذا المستودع: `1.1.0+1` (الوسم المقصود `v1.1.0`).

تطبيق إدارة أصلي مستقل مبني باستخدام Flutter، للاستخدام الإداري المحلي على Android وWindows. المشروع مستقل وظيفيًا داخل المستودع الموحد، ولا ينسخ واجهات الموقع أو لوحة التحكم القديمة؛ ولا ينسخ واجهات الموقع أو لوحة التحكم القديمة. يعتمد التصميم على نظام مكونات خاص بالتطبيق، مع العربية وRTL فقط.

## حالة المشروع

الأساس الحالي يتضمن:
- واجهة تسجيل دخول عربية.
- حفظ الجلسة في التخزين الآمن.
- لوحة معلومات عربية أصلية مرتبطة بمسار API الحالي، تعرض مؤشرات الطلاب والموظفين والمواد والمحتوى والإعلانات والتعليقات.
- تُعرض المقترحات والبلاغات العامة وبلاغات الدردشة في صفحة موحّدة لمدير النظام، مع تمييز نوع كل سجل والحفاظ على إجراءات API الخاصة به.
- تنقل يراعي معرّفات أدوار Backend المعروفة: `super_admin` و`content_manager` و`academic_manager`؛ وهذا لا يستبدل صلاحيات الخادم.
- تنقل متجاوب للشاشات الصغيرة والكبيرة.
- عميل API يدعم GET وPOST وPUT وPATCH وDELETE.
- تدوير رمز التحديث عبر `/auth/refresh` عند انتهاء رمز الوصول.
- اختبارات عميل API وقواعد التنقل حسب الدور وGitHub Actions لبناء المنصات.

الوحدات الإدارية الأخرى لا تزال قيد التنفيذ. لا تعتبر هذه النسخة إصدارًا إنتاجيًا قبل نجاح CI والاختبارات على المنصات المستهدفة.

## المتطلبات

- Flutter stable المتوافق مع قيود `pubspec.yaml`.
- Android: Android SDK.
- iOS: macOS وXcode للبناء والتوقيع والتثبيت على الأجهزة.
- Windows: Windows مع Visual Studio وعبء عمل Desktop development with C++.

## تجهيز ملفات المنصات وتشغيل التطبيق

```bash
flutter create --platforms=android,windows .
flutter pub get
flutter analyze
flutter test
```

## تشغيل محلي

```bash
flutter run -d windows
```

أو اختر جهاز Android متصلًا/محاكيًا من قائمة `flutter devices`.

## بناء محلي

Android APK للتثبيت المحلي:

```bash
flutter build apk --release --dart-define=TRINEX_API_BASE_URL=https://YOUR_API_HOST/api/v1
```

Windows:

```bash
flutter build windows --release --dart-define=TRINEX_API_BASE_URL=https://YOUR_API_HOST/api/v1
```
لا تُنتج حزمة AAB؛ التوزيع المستهدف محلي. بناء iOS مستبعد من عملية البناء الحالية.

## اتصال Android بالشبكة

ينشئ CI ملفات Android قبل البناء، ثم يتحقق من وجود تصريح
`android.permission.INTERNET` في `AndroidManifest.xml` ويضيفه إذا كان غائبًا.
هذا التصريح ضروري حتى يستطيع APK الاتصال بخدمة API عبر HTTPS. بعد كل بناء،
يجب اختبار اتصال `/health` على الجهاز الفعلي؛ فنجاح البناء وحده لا يثبت أن نطاق
Cloudflare قابل للحل أو أن الخدمة متاحة.

## إعداد عنوان API

عنوان الخدمة الافتراضي مضبوط في `lib/src/api_service.dart` لمطابقة نسخة Backend الحالية المرفقة. غيّره وقت البناء باستخدام `TRINEX_API_BASE_URL`. لا تضع كلمات مرور أو مفاتيح إدارية أو أسرار توقيع في المستودع أو داخل التطبيق.

المسارات الحالية التي تم التحقق من وجودها في Backend المرفق:
- `POST /auth/staff/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /admin/dashboard/overview`
- `GET /admin/security/eino-usage?hours=24`
- `GET /health`

وجود المسار في الكود لا يثبت توفره في بيئة الإنتاج؛ يجب اختبار الاتصال باستخدام حساب اختبار مصرح به.

## المستودع وCI

ملف `../../.github/workflows/admin-ci.yml` يفحص التنسيق والتحليل والاختبارات، ويبني Android APK وWindows. لا ينشر هذا الـworkflow التطبيق إلى متجر أو إلى خدمة إنتاجية.

## الأمان والحدود المعروفة

- صلاحيات الخادم هي المرجع النهائي؛ إخفاء عناصر الواجهة ليس بديلًا عن فحص الصلاحيات في API.
- رمز التحديث أحادي الاستخدام في Backend الحالي، لذلك يجب حفظ الرمز الجديد بعد كل تحديث ناجح.
- لا تشارك ملفات البناء الموقعة أو بيانات اعتماد الإدارة في المستودع.
- تم تنفيذ الوظائف الأساسية لإدارة الطلاب والموظفين والمحتوى والمواد والجداول، لكنها لم تُختبر تكامليًا على خادم حي. لا تزال سجلات الأمان والإعدادات والحساب والفعاليات التعليمية بحاجة إلى استكمال.

## حالة الوحدات

- لوحة المعلومات: موصولة بمسار الإحصائيات.
- الإشراف الطلابي: يُمنح منصب مشرف الطالب من قائمة الطالب في صفحة الطلاب، ويتيح حذف التعليقات والردود ورسائل المحادثة العامة. يتحقق الـBackend من المنصب في كل عملية حذف.
- إدارة المحتوى: CRUD أساسي للأخبار والفعاليات والإنجازات مع حقول روابط الصور؛ والإعلانات لمدير النظام فقط في الواجهة الحالية.
- الإشعارات: سجل الإعلانات المنشورة وإرسال/تحديث الاستهداف عبر API. إدراج الإشعار في قوائم التسليم لا يثبت وصول Push إلى الجهاز؛ ذلك يعتمد على إعداد عامل التسليم بالخادم.
- رفع الوسائط: رفع صورة JPEG/PNG/WebP حتى 3 ميغابايت عبر `/admin/media` ونسخ الرابط لاستخدامه في المحتوى؛ يعتمد على تهيئة مخزن الوسائط في الخادم.
- إدارة الطلاب: بحث وعرض وإنشاء وتعديل وتفعيل/إيقاف وحذف مؤكد.
- الموظفون والصلاحيات: إنشاء وتعديل وتعطيل/تفعيل وحذف مؤكد وتعيين الأدوار، مع قيود الخادم على تعديل حساب المستخدم الحالي.
- المواد والجداول الأكاديمية: CRUD ومزامنة Google Drive الأساسية.
- أُضيفت مراقبة Eino التفصيلية، ودُمجت المقترحات والبلاغات العامة وبلاغات الدردشة في صندوق مراجعة موحّد، وربط رفع الصور من محرر المحتوى. لم تُشغّل اختبارات Flutter والبناء الفعلي في بيئة التحرير؛ راجع `docs/ADMIN_PARITY_AUDIT.md` لمصفوفة الربط وحدود التحقق.

عمليات رفع الصور وإرسال الإعلانات الموجهة غير مشمولة بعد في نموذج إدارة المحتوى. راجع `docs/API_CONTRACT_AUDIT.md` قبل توسيع أي مورد.

## Academic administration

The academic workspace includes subject, material, and schedule CRUD screens plus Google Drive sync status/actions. It consumes the existing backend endpoints; Google Drive credentials remain server-side. See `docs/API_CONTRACT_AUDIT.md` for the reviewed routes and `docs/IMPLEMENTATION_PLAN.md` for limitations and verification status.


## Student and staff administration

The student and staff screens use the current backend contracts directly. Student deletion and staff deletion are permanent operations and require confirmation. Staff roles are limited to `super_admin`, `content_manager`, and `academic_manager`. Student moderation is a separate `students.is_moderator` privilege; legacy staff `moderator` accounts receive no privileged API permissions.

### Phase 7 — Account and security

- Account screen supports changing the signed-in staff password using the backend's current-password verification endpoint.
- Security screen displays audit history and failed/locked authentication events in read-only mode.
- Settings screen exposes only public display settings (`public.*`) and the legacy `Logo` key, with JSON validation.
- These integrations were checked against the supplied backend source. They are not a claim of live-production or native-build verification.

## Latest progress

See [`docs/PHASE8_AUDIT.md`](docs/PHASE8_AUDIT.md) for the security/integration audit, session-refresh concurrency fix, and remaining release gates.


## Admin parity

راجع [`docs/ADMIN_PARITY_AUDIT.md`](docs/ADMIN_PARITY_AUDIT.md) لمقارنة وظائف لوحة الويب السابقة بالشاشات الأصلية وعقود API، مع بيان ما لم يُتحقق منه على خادم حي.


### Phase 2 — Usage resource analytics and student moderation
- The analytics screen reports normalized API request counts, response duration, 5xx errors, executed D1 operations, D1 row metadata, instrumented R2 operations/bytes, the application media storage ledger, and the top three API routes by request/D1/R2 use.
- These are application-observed operational metrics, not Cloudflare account billing, Worker CPU-time, or provider-wide storage analytics. Exact account usage requires a separately authorized Cloudflare Analytics/API integration.
- The admin navigation no longer includes the standalone moderation page or assignable staff moderator role. Student moderators are granted/revoked from the Students page.
- Backend migration `0040_student_moderators_and_resource_usage.sql` is required before deploying the updated Worker or app clients. See `docs/USAGE_ANALYTICS_RESOURCE_METRICS_AND_STUDENT_MODERATION.md`.
\n\n## App identity and supported build targets\n\n- Display name: **TRINEX Admin**.\n- Android: release APK with generated launcher icon.\n- Windows: release desktop build with generated application icon.\n- iOS is intentionally excluded from the current CI/build workflow; it can be reintroduced later without changing the Android or Windows targets.\n
# خطة تنفيذ TRINEX-Admin

## المرحلة 0 — التدقيق وتثبيت العقود

- [x] تأكيد أن المستودع مستقل عن `Union-App`.
- [x] تأكيد المنصات المستهدفة حاليًا: Android وWindows؛ تأجيل iOS لحين توفر بيئة macOS.
- [x] اعتماد العربية فقط وRTL.
- [x] حذف AAB من مخرجات الإصدار المستهدفة.
- [x] بدء مراجعة مسارات API من نسخة Backend المرفقة.
- [ ] اعتماد مصدر الحقيقة وقرار التوافق بين Backend الحالي والمعمارية المستهدفة.
- [x] مطابقة معرّفات الأدوار الأربعة مع Backend الحالي (مع إبقاء اعتماد الصلاحية النهائي للخادم).
- [ ] جرد تفصيلي لكل شاشة/عملية API وحالة تنفيذها.

## المرحلة 1 — أساس التطبيق

- [x] فرض العربية وRTL على مستوى التطبيق.
- [x] إضافة دعم GET/POST/PATCH/PUT/DELETE في عميل API مع حقن HTTP client للاختبار.
- [x] معالجة الاستجابات المغلفة والأخطاء المتداخلة والمهلات.
- [x] تنفيذ تدوير الجلسة باستخدام `/auth/refresh` وفق عقد الخادم الفعلي.
- [x] إنشاء نظام تصميم أصلي مبدئي للألوان والبطاقات والحقول والأزرار والتنقل في `lib/src/design_system/trinex_theme.dart`.
- [x] إعداد CI لتوليد ملفات Android/Windows والتحقق من بنائها في بيئاتها المناسبة.
- [ ] تشغيل CI بنجاح وحفظ نتيجة بناء فعلية لكل منصة.
- [x] إضافة اختبارات API أولية باستخدام عميل HTTP وهمي.
- [x] إضافة اختبارات وحدات لقواعد إظهار الأقسام حسب الدور واختبار أولوية staffRoleId.
- [ ] تشغيل الاختبارات فعليًا وإضافة تغطية widget وتكامل.

## المرحلة 2 — الهوية والأمان

- [ ] تسجيل الدخول والخروج واستعادة الجلسة.
- [ ] التعامل مع انتهاء الرمز وتجديده مرة واحدة عند الحاجة دون حلقات إعادة محاولة.
- [ ] جلب ملف الموظف وصلاحياته التفصيلية من الخادم؛ معرّف الدور الأساسي يُقرأ من `staffRoleId`.
- [x] تصفية التنقل بحسب معرّفات الأدوار المعروفة كتحسين تجربة؛ الخادم يظل صاحب القرار الأمني.
- [ ] إضافة اختبار تكامل يثبت رفض الخادم للطلبات غير المصرح بها.
- [ ] اختبارات نجاح/فشل الدخول، انتهاء الجلسة، ورفض الصلاحية.

## المرحلة 3 — لوحة المعلومات

- [x] بناء لوحة معلومات عربية أصلية من الصفر مع مؤشرات فعلية من API وروابط وصول سريع بحسب الدور.
- [x] عرض مؤشرات API المعتمدة فقط (طلاب، موظفون، مواد، أخبار، إعلانات، تعليقات ظاهرة).
- [x] حالات تحميل/خطأ وإعادة المحاولة مع الاحتفاظ بآخر بيانات ناجحة أثناء فشل التحديث.
- [ ] اختبار البيانات غير المكتملة والاستجابات المغلفة داخل `data`.

## المرحلة 4 — الوحدات الإدارية

تنفذ كل وحدة عبر دورة موحدة: تدقيق عقد API، النماذج، الواجهة، CRUD، الصلاحيات، الأخطاء، والاختبارات.

- [x] المحتوى والأخبار والإعلانات والفعاليات والإنجازات (CRUD أساسي، مع حقل رابط الصورة).
- [x] الطلاب: قراءة وبحث وإنشاء وتعديل وتفعيل/إيقاف وحذف مع تحذير للأثر التابع.
- [x] الموظفون والأدوار: إنشاء وتعديل وتعطيل/تفعيل وحذف وإعادة تعيين كلمة مرور لحسابات أخرى عبر API.
- [x] المواد الدراسية وGoogle Drive: CRUD ومزامنة وفحص حالة المزامنة.
- [x] الجداول والمواد الأكاديمية: CRUD أساسي.
- [x] الإشراف على التعليقات والردود: عرض حسب الحالة، إظهار/إخفاء، تعليم التعليق كمحذوف، وحذف الرد نهائيًا بعد التأكيد.
- [x] شاشة الإشعارات: قراءة السجل، النشر المباشر أو جدولة موعد مستقبلي، البحث والتصفية، التحرير والحذف، واختيار الجمهور عبر مسارات `/admin/notifications` و`/admin/announcements` و`/admin/notifications/send`؛ يتطلب التفعيل والإرسال التلقائي عند الموعد تأكيد منطق الخادم.
- [ ] إنشاء/تحرير الفعاليات التعليمية (`/admin/learning-events`) وربط نموذج تصميمها وXP.
- [ ] سجل التدقيق وأحداث المصادقة.
- [ ] مراقبة Eino.
- [ ] الإعدادات والحساب وتغيير كلمة المرور.

## المرحلة 5 — المنصات والتوزيع المحلي

- [ ] Android APK للتثبيت المحلي؛ لا AAB.
- [ ] Windows Release مع تعليمات التثبيت والتبعيات.
- [ ] تأجيل بناء iOS والتوقيع إلى حين توفر جهاز Mac.
- [ ] إعداد CI لكل منصة ضمن حدود بيئة البناء المتاحة.
- [ ] عدم إعلان نجاح أي منصة قبل نجاح build فعلي واختبار تشغيل.

## المرحلة 6 — بوابة الإصدار

- [ ] لا أخطاء تحليل/بناء حرجة.
- [ ] اختبارات المصادقة والصلاحيات والعمليات الأساسية ناجحة.
- [ ] لا أسرار ضمن المستودع.
- [ ] اختبار على جهاز Android فعلي أو محاكي.
- [ ] اختبار Windows على بيئة Windows.
- [ ] تأجيل اختبار iOS إلى حين توفر بيئة macOS/Xcode.
- [ ] تسليم سجل بما اكتمل وما بقي والمخاطر المعروفة.

## حالة التنفيذ — دفعة إدارة المحتوى

- [x] ربط شاشة إدارة المحتوى بمسارات CRUD العامة للأخبار والفعاليات والإنجازات.
- [x] إضافة إنشاء وتعديل وحذف مع تأكيد الحذف.
- [x] إضافة بحث محلي وتصفية بحسب حالة النشر.
- [x] حصر ظهور الإعلانات في مدير النظام في الواجهة الحالية، اتساقًا مع صلاحيات Backend الحالية.
- [ ] رفع الصور عبر `/admin/media` وربط ملكية الوسائط بالسجل.
- [x] اختيار القسم والفصل المستهدفين للإعلانات من القوائم المتاحة، مع إرسال/تحديث الاستهداف عبر `/admin/notifications/send`.
- [ ] تشغيل `dart format`, `flutter analyze`, `flutter test` وعمليات البناء على CI؛ لم تُنفذ محليًا لعدم توفر Flutter SDK في بيئة التحرير.

## Progress update — Academic module

Implemented in the Phase 4 working copy:
- Academic workspace with tabs for subjects, materials, schedules, and Google Drive sync history.
- CRUD operations use the existing `/admin/subjects`, `/admin/materials`, and `/admin/schedule` endpoints.
- Department and semester choices are loaded from the existing `/departments` and `/semesters` endpoints.
- Drive sync and sync status use `/admin/drive/sync` and `/admin/drive/sync-status`; the user must confirm before triggering a sync.
- Delete confirmation warns that deleting a Drive-backed material may delete its linked Drive file depending on backend configuration.

Not yet verified: Flutter analyzer/tests and native builds. The workspace currently relies on the existing API's CRUD contracts; it does not implement file upload, direct Drive browsing, or manual changes to Google Drive permissions.


## Progress update — Student and staff administration (Phase 5)

- Implemented student search/listing, create/edit, active-state toggle, and confirmed hard delete using `/admin/students`; department and semester choices come from `/departments` and `/semesters`.
- Implemented staff account listing, create/edit, role assignment, active-state toggle, password reset for other staff accounts, and confirmed deletion using `/admin/staff`.
- The role selector presents the four approved role labels while retaining the existing backend role IDs: `super_admin`, `moderator`, `content_manager`, and `academic_manager`. Important contract limitation: backend `moderator` currently only grants moderation/notification permissions; the UI does not silently broaden its authority.
- Academic managers can now see the student section in navigation, matching the backend's `academic.read` / `academic.write` rule for `/admin/students`. Backend authorization remains authoritative.
- Not verified: Dart formatting/analyzer, Flutter tests, API integration against production, or native builds; the current editing environment has no Flutter/Dart SDK.


## Progress update — Notifications and media (Phase 6)

- Added notifications workspace backed by `GET /admin/notifications?limit=100` and `POST /admin/notifications/send` with confirmation before queuing targets. The UI explicitly states that push delivery depends on server-side dispatch configuration; queuing is not represented as confirmed device delivery.
- Added image upload workspace backed by `POST /admin/media`, with multipart field `file`, client-side type/size checks, and a server-returned URL that can be copied. The server remains authoritative for image signatures, 3 MB limits, quotas, and R2 configuration.
- Added `ApiService.uploadImage` with authenticated multipart requests and one refresh/retry path for HTTP 401.
- Added optional `image_url` fields to news, events, and achievements editors so uploaded URLs can be attached to supported records.
- Navigation visibility matches current backend permissions: media for `super_admin` and `content_manager`; notifications for `super_admin` and `moderator`.
- Not implemented in this phase: image picker embedded inside each content editor, direct media deletion/attachment reconciliation, push-provider delivery worker, or learning-event authoring.
- Not verified: Dart formatting, analyzer, Flutter tests, API smoke tests, or native builds because Flutter/Dart SDK is unavailable in this editing environment.

## Phase 7 — Account, audit and public settings

- Added account page with current-password verification and new-password confirmation, wired to `POST /auth/staff/change-password`. Backend keeps the current session and revokes other sessions after a successful change.
- Added read-only audit history from `GET /admin/audit-logs?limit=100` and failed/locked authentication events from `GET /admin/security/auth-events?limit=100`. Both are limited by backend permissions; the app does not attempt to clear or mutate audit data.
- Added a constrained settings editor for `public.*` and the legacy `Logo` key through the existing `/admin/settings` handler. Values must parse as JSON. Other app_settings keys are intentionally hidden in the client to avoid exposing or modifying unknown settings.
- Static contract review only: these routes and request fields were checked against the supplied `Union-App` source. Live production requests, Flutter analysis, widget tests, and platform builds have not been run in this environment.


## Phase 8 — Audit

- Session refresh requests are coalesced to avoid rotating a single-use refresh token concurrently.
- Audit-detail view redacts sensitive fields and safely hides malformed metadata JSON.
- Backend JavaScript syntax check passed; Flutter analysis/tests/builds remain pending because the SDK is unavailable in the current environment.
- Full details and release gates: `docs/PHASE8_AUDIT.md`.


## Phase 2 update (2026-10-14)
The legacy staff moderator role and moderation navigation have been removed. The Students page grants/revokes the separate student moderator flag. Usage analytics now display server/API activity, D1 operations, R2 operations/bytes, the app's media-storage ledger and top-three normalized API routes. Backend migration 0040 must be applied before use. Exact Cloudflare account-level usage and Worker CPU metrics are not available from these application-side counters.


## Phase 2 update (2026-10-14)
The legacy staff moderator role and moderation navigation have been removed. The Students page grants/revokes the separate student moderator flag. Usage analytics now display server/API activity, D1 operations, R2 operations/bytes, the app's media-storage ledger and top-three normalized API routes. Backend migration 0040 must be applied before use. Exact Cloudflare account-level usage and Worker CPU metrics are not available from these application-side counters.

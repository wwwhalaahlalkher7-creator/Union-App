# تدقيق أولي لعقد API — Union-App المرفق

> هذه ملاحظات من قراءة المصدر المحلي في أرشيف `Union-App.zip`، وليست اختبارًا حيًا للخادم المنشور.

## مسارات مؤكدة في `backend/src/index.js`

| العملية | المسار | الطريقة | ملاحظات التنفيذ |
|---|---|---|---|
| صحة الخدمة | `/health` | GET | لا يحتاج جلسة بحسب الاستخدام الحالي |
| دخول الموظف | `/auth/staff/login` | POST | الجسم: `userId`, `password` |
| تجديد الجلسة | `/auth/refresh` | POST | أضيف استخدامه لتدوير رمز التحديث في عميل API |
| خروج الموظف | `/auth/logout` | POST | التطبيق يحاول الطلب ثم يمسح الجلسة محليًا |
| هوية الموظف | `/auth/staff/me` | GET | يجب فحص شكل الاستجابة قبل ربط الحالة والصلاحيات |
| تغيير كلمة المرور | `/auth/staff/change-password` | POST | يحتاج واجهة تحقق وتأكيد |
| نظرة عامة | `/admin/dashboard/overview` | GET | موصول حاليًا من Flutter |
| استخدام Eino | `/admin/security/eino-usage` | GET | موصول مبدئيًا من Flutter |
| مراقبة Eino | `/admin/security/eino-monitor` | GET | موجود في Backend؛ لا توجد شاشة مكتملة في Flutter |
| سجل المصادقة | `/admin/security/auth-events` | GET | محمي بصلاحية مرتفعة |
| سجل التدقيق | `/admin/audit-logs` | GET | محمي بصلاحية مرتفعة |
| الطلاب | `/admin/students` | GET/POST/عمليات حسب المورد | المورد ضمن CRUD العام؛ يجب فحص PATCH/DELETE ومساراته قبل تنفيذ العميل |
| الموظفون | `/admin/staff` | GET/POST/PATCH/DELETE | يجب ربط نموذج الأدوار الفعلي وعدم افتراض أدوار أخرى |
| الإشراف | `/admin/moderation/comments` | GET/PATCH | يتضمن حالات الإشراف |
| الردود | `/admin/moderation/replies` | GET/PATCH/DELETE | يحتاج واجهة إدارة فعلية |
| مزامنة Drive | `/admin/drive/sync` | POST | يتطلب عرض حالة المزامنة ومعالجة الأخطاء |
| حالة مزامنة Drive | `/admin/drive/sync-status` | GET | يجب التحقق من شكل الاستجابة |
| رفع وسائط | `/admin/media` | POST | يجب فحص نوع الجسم والحدود قبل تصميم الرفع |

## قيود ظهرت في تطبيق البداية

- أصبح `ApiService` يدعم `GET` و`POST` و`PUT` و`PATCH` و`DELETE`؛ يجب التأكد من أن كل مورد يدعم الطريقة المطلوبة قبل استدعائها.
- أضيف تدوير رمز التحديث عبر `/auth/refresh`، مع حفظ الرمز الجديد لأن رموز التحديث أحادية الاستخدام في Backend الحالي.
- أضيفت اختبارات عميل API أولية للغلاف `data` وAuthorization وطرق HTTP وتدوير الجلسة؛ لا تزال اختبارات الصلاحيات وتدفقات المصادقة الكاملة مطلوبة.
- ملفات منصات Android/iOS/Windows لا تزال غير مولّدة داخل الأرشيف؛ أضيف CI لتوليد ملفات المنصات في بيئة البناء والتحقق من كل هدف. يلزم تشغيل CI قبل اعتبار دعم المنصات مثبتًا.
- الاستجابات قد تكون مغلفة في `data`، بينما أخطاء Backend الفعلية تتضمن غالبًا كائن `error` داخليًا يحوي `message` و`code`؛ أصبح فك الأخطاء يقرأ `error.message` في صيغة Backend المتداخلة، مع دعم `message` المباشر.
- أسماء الأدوار التي يعلنها Backend الحالي: `super_admin`, `content_manager`, `academic_manager`, `moderator`. لا ينبغي تبديلها تلقائيًا إلى أسماء أخرى قبل اعتماد خريطة صريحة.

## المسارات العامة للإدارة

يعالج `backend/src/admin.js` موارد الإدارة العامة ويختار الصلاحية بناءً على المورد وطريقة HTTP. موارد CRUD المعروفة في `adminResourceTable` تشمل الأخبار والإعلانات والفعاليات والإنجازات والمواد والمواد الأكاديمية والجداول والطلاب والتعليقات. الموظفون والإعدادات وسجلات التدقيق لها معالجات خاصة.

قبل تنفيذ أي وحدة، يجب مراجعة `backend/src/admin.js` و`backend/src/admin/config.js` والتحقق من الحقول المسموح بها وعمليات الحذف/التعديل والتحقق من العلاقات الأكاديمية. لا تُنشأ مسارات غير موجودة اعتمادًا على أسماء صفحات الويب.

## تحقق إضافي — الإشراف ومعرّفات الأدوار (دفعة التنفيذ التالية)

تمت مطابقة المسارات التالية مباشرةً مع معالجات `backend/src/index.js` في أرشيف Union-App المرفق:

- `GET /admin/moderation/comments?status=visible&limit=100`
- `PATCH /admin/moderation/comments/:id` مع `status` من `visible | hidden | deleted`
- `GET /admin/moderation/replies?status=visible&limit=100`
- `PATCH /admin/moderation/replies/:id` مع `status` من `visible | hidden | deleted`
- `DELETE /admin/moderation/replies/:id` للحذف النهائي للرد

الأدوار المعروفة في Backend هي معرّفات `super_admin` و`content_manager` و`academic_manager` و`moderator`. يجب أن يستخدم التطبيق `staffRoleId` للمطابقة البرمجية؛ `staffRole` اسم عرض قابل للقراءة مثل `Super Admin` وليس معرّف الصلاحية. تصفية التنقل في التطبيق تحسين تجربة فقط، والتحقق النهائي يبقى في Backend.

هذه مطابقة ساكنة للكود المرفق، وليست إثباتًا لنجاح الطلبات على بيئة الإنتاج. وحدة الإشراف تحتاج اختبار تكامل باستخدام حسابات تجريبية لكل دور.

## وحدة إدارة المحتوى — مطابقة إضافية

تمت إضافة واجهة Flutter لإدارة الموارد التالية باستخدام CRUD العام الموجود في `backend/src/admin.js` وحقول `ADMIN_FIELDS` في `backend/src/admin/config.js`:

- الأخبار: `/admin/news` — الحقول الأساسية `title`, `body`, `status` مع `category` و`publisher`.
- الفعاليات: `/admin/events` — الحقول الأساسية `title`, `body`, `status` مع `category`, `publisher`, `location`, `event_at`, `end_at`.
- الإنجازات: `/admin/achievements` — الحقول `title`, `description`, `status` مع `publisher`, `badge`, `achieved_at`.
- الإعلانات: `/admin/announcements` — الحقول `title`, `body`, `type`, `status`.

العمليات المتاحة في المعالج العام تشمل `GET` و`POST` و`PATCH` و`DELETE` وفق الصلاحية المشتقة من المورد والطريقة. الواجهة لا تعتبر تصفية الأدوار بديلًا عن التحقق من Backend. أُظهر قسم الإعلانات في هذه الواجهة لمدير النظام فقط؛ لأن Backend يربط هذا المورد بصلاحيات الإشعارات، ولا يملك مدير المحتوى صلاحية الكتابة فيه في الإعداد الحالي.

نموذج المحتوى العام لا ينفذ رفع الصور أو اختيار الجمهور الأكاديمي للإعلانات أو تجهيز قائمة الإرسال؛ يدير قسم الإشعارات هذه العمليات في شاشة مستقلة عبر `/admin/media` و`/admin/notifications/send` والعقد العام للإعلانات. حقول التوقيت اختيارية وتُرسل بصيغة ISO؛ لم يُختبر تطبيق موعد النشر فعليًا على الخادم المنشور ضمن هذه الدفعة.

## Academic administration endpoints reviewed

- `GET /api/v1/departments` — active departments for form choices.
- `GET /api/v1/semesters` — active semesters for form choices.
- `GET|POST /api/v1/admin/subjects` and `PATCH|DELETE /api/v1/admin/subjects/:id` — subject CRUD.
- `GET|POST /api/v1/admin/materials` and `PATCH|DELETE /api/v1/admin/materials/:id` — material metadata CRUD. The backend may delete the linked Drive file during a material delete, so the UI requires confirmation.
- `GET|POST /api/v1/admin/schedule` and `PATCH|DELETE /api/v1/admin/schedule/:id` — schedule CRUD. The backend validates subject/department/semester consistency and time ranges.
- `POST /api/v1/admin/drive/sync` — starts a Drive index synchronization, requiring `super_admin` or `academic_manager`.
- `GET /api/v1/admin/drive/sync-status` — returns the latest synchronization runs, with the same role restriction.

These routes were found in the supplied Union-App backend source. No live production requests were made during this implementation pass.


## Student and staff administration — contract review

- `GET|POST /admin/students`, `PATCH|DELETE /admin/students/:id`: generic CRUD backed by `ADMIN_SELECT_COLUMNS.students` and `ADMIN_FIELDS.students`. Required creation fields are `student_number`, `full_name`, and `department_id`; the backend validates student-number format, email uniqueness/format, and academic references. The response exposes a `registered` flag, not credentials. Deleting a student is a hard delete and removes related interaction records, so the UI offers a warning and an inactive-state alternative.
- `GET|POST /admin/staff`, `PATCH|DELETE /admin/staff/:id`: special handler in `adminStaff`. Creation requires username, display name, and password of at least 8 characters. Role IDs are validated against `ADMIN_ROLE_IDS`; a password reset for another staff account revokes its sessions. The backend prevents self-delete, self-deactivation, self-role-change, and administrative password reset of the current account.
- Permission rule: student read/write uses `academic.read` / `academic.write`; staff list and writes require `superadmin.read` / `superadmin.write`. UI visibility is not a security boundary.
- Role label mapping in this client: `super_admin` → Super Admin, `moderator` → Admin, `content_manager` → Editor, `academic_manager` → Academic Admin. This is a label mapping only. The current backend's `moderator` permission set is limited to moderation and notifications, so it must not be interpreted as a broad administrator role without an explicit backend change.
- No live production API calls or end-to-end tests were performed.

## Phase 7 — account/security/settings integration

- `POST /auth/staff/change-password` expects `currentPassword` and `newPassword`; the backend validates the current secret, requires 8–256 characters for the new secret, and revokes other sessions while retaining the current one.
- `GET /admin/audit-logs?limit=100` returns audit entries; `GET /admin/security/auth-events?limit=100` returns selected failed/locked authentication events. Both require elevated permissions. They are read-only in the app.
- `GET /admin/settings` and `PUT /admin/settings/:key` are the existing settings endpoints. The UI intentionally limits displayed/editable keys to `public.*` and `Logo`, and validates values as JSON before sending them. This is a UI restriction; backend authorization remains authoritative.
- No live production API calls or Dart analyzer/build commands were possible in the current environment.


## Phase 2 contract update (2026-10-14)
The staff `moderator` role is no longer an approved/privileged role. Only `super_admin`, `content_manager`, and `academic_manager` are assignable. Student moderators are represented by `students.is_moderator` and managed through `PATCH /api/v1/admin/students/{id}/moderator` with `{ "isModerator": true|false }`; the endpoint requires `academic.write`. Student-authenticated deletion endpoints independently enforce the flag.


## Phase 2 contract update (2026-10-14)
The staff `moderator` role is no longer an approved/privileged role. Only `super_admin`, `content_manager`, and `academic_manager` are assignable. Student moderators are represented by `students.is_moderator` and managed through `PATCH /api/v1/admin/students/{id}/moderator` with `{ "isModerator": true|false }`; the endpoint requires `academic.write`. Student-authenticated deletion endpoints independently enforce the flag.

# تغطية وحدات الإدارة المعتمدة على Backend

يوضح الجدول التالي ما توفره واجهة الإدارة داخل المستودع الموحد وما يطابقه فعلًا في المصدر المحلي للخادم. لا تعني هذه المطابقة أن بيئة الإنتاج أو أسرار الخدمات الخارجية مضبوطة.

| الوحدة | الواجهة | العقد الفعلي | التغطية |
|---|---|---|---|
| لوحة المعلومات | نظرة عامة | `/admin/dashboard/overview` | الأعداد المدعومة من الخادم |
| المحتوى | أخبار، فعاليات، إنجازات | `/admin/news`, `/admin/events`, `/admin/achievements` | إنشاء وتعديل وحذف ونشر/جدولة وفق الحقول المتاحة؛ صور عبر `/admin/media` |
| الإشعارات | الإعلانات والجمهور والتوقيت والإرسال | `/admin/announcements`, `/admin/notifications`, `/admin/notifications/send` | إدارة السجل وتجهيز إرسال الإشعار بعد تأكيد المشرف |
| الطلاب | `StudentsPage` | `/admin/students`, `/departments`, `/semesters` | CRUD وحالة الحساب؛ لا يوجد خيار مشرف طالب لأن Backend لا يدعمه |
| حسابات الإدارة | `StaffPage` | `/admin/staff` | CRUD ودور الحساب وحالته وكلمة مرور حساب آخر وفق قيود الخادم |
| المواد والجداول | `AcademicPage` | `/admin/subjects`, `/admin/materials`, `/admin/schedule` | CRUD مع التحقق من المراجع الأكاديمية |
| Google Drive | الإدارة الأكاديمية | `/admin/drive/sync`, `/admin/drive/sync-status`, `/admin/drive/folders`, `/admin/drive/items/:id`, `/admin/drive/files` | مزامنة وإنشاء مجلد ورفع/إعادة تسمية ملفات PDF وحدها الأقصى الذي يفرضه الخادم |
| الامتحانات | إدارة إضافية | `/admin/exams` | تجهيز مجلد، رفع، إعادة تسمية وحذف PDF |
| السوق | إدارة إضافية | `/admin/market-items` | CRUD كامل |
| الشارات | إدارة إضافية | `/admin/badges` | إنشاء/تعديل/تفعيل/تعطيل دون حذف نهائي |
| إشراف التعليقات | `FeedbackReportsPage` | `/admin/moderation/comments` | تغيير حالة التعليق إلى ظاهر/مخفي/محذوف |
| إحصاءات Eino | `EinoMonitorPage` | `/admin/security/eino-usage` | عدد الأحداث والمتوسطات والمجموعات الزمنية والحدود التي يعيدها الخادم؛ بيانات مجمعة |
| أمان وسجل تدقيق | `SecurityPage` | `/admin/audit-logs`, `/admin/security/auth-events` | عرض فقط مع حجب الحقول الحساسة |
| إعدادات الموقع | `SettingsPage` | `/admin/settings` | قراءة وإدارة قيم الإعدادات بصيغة JSON؛ يجب توخي الحذر عند تغيير القيم التقنية |
| حسابي | `AccountPage` | `/auth/staff/me`, `/auth/staff/change-password` | قراءة ملف الموظف وتغيير كلمة المرور؛ لا يدعم الخادم تعديل الاسم أو البريد |

## وظائف مستبعدة عمدًا لغياب عقد Backend

- استيراد الطلاب والجداول باستخدام الماسح ومسارات `/admin/imports*`.
- تعيين طالب كمشرف عبر `/admin/students/:id/moderator`.
- تحليلات تفصيلية عبر `/admin/analytics/overview`.
- صناديق الإشراف/البلاغات عبر `/admin/moderation/inbox`, `/admin/moderation/chat-reports` أو `/admin/moderation/feedback`.
- مسار مراقبة قديم `/admin/security/eino-monitor`؛ المسار الصحيح هو `/admin/security/eino-usage`.

لا يجوز إعادة إضافة هذه الوظائف في واجهة الإدارة قبل توفير المعالجات الفعلية واختبارات العقد والصلاحيات في `services/api`.

## توافق التنقل مع الأدوار

- `super_admin`: جميع وحدات الإدارة.
- `content_manager`: المحتوى والسوق والشارات ولوحة المعلومات وإحصاءات Eino.
- `academic_manager`: الطلاب والمواد والجداول وDrive والامتحانات ولوحة المعلومات وإحصاءات Eino.
- `moderator`: إشراف التعليقات والإشعارات ولوحة المعلومات وإحصاءات Eino.

إخفاء العناصر في الواجهة لا يمنح صلاحية جديدة؛ كل عمليات القراءة والتغيير ما تزال خاضعة لقواعد الصلاحيات في الـBackend.

## ملاحظات الإصدار والتحقق

تطبيق الإدارة `1.1.0+1` وتطبيق الطلاب `2.0.3+2` يحتفظ كل منهما بإصدار مستقل داخل المونو-ريبوزتري. يتولى `.github/workflows/admin-ci.yml` تحليل تطبيق الإدارة واختباراته وبناء APK وWindows. بيئة التحرير هذه لا تحتوي على Flutter SDK؛ لم يُنفّذ بناء محلي أو اختبار API حي، لذا يتطلب الإصدار التحقق الأخضر من GitHub Actions قبل اعتباره جاهزًا للنشر.

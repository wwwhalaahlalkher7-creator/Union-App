# TRINEX-Admin — المعمارية المستهدفة

## حدود المشروع

- مستودع مستقل عن `Union-App`.
- تطبيق Flutter أصلي واحد يستهدف Android وWindows؛ iOS مستبعد من البناء الحالي.
- لغة الواجهة الحالية: العربية فقط، مع فرض RTL على مستوى التطبيق.
- التطبيق محلي للاستخدام الإداري؛ لا توجد حاجة إلى إصدار Android App Bundle (AAB) أو إعداد نشر على متجر Google Play.
- استقلال المستودع لا يعني إنشاء قاعدة بيانات مستقلة: التطبيق يتصل بخدمات TRINEX عبر API موثق، ومصدر البيانات المعتمد يُحسم في مرحلة تثبيت المعمارية.

## طبقات التطبيق

1. `app/`: التهيئة، التوجيه، اتجاه اللغة والثيم.
2. `core/api/`: النقل HTTP، تحويل الاستجابات، معالجة الأخطاء والمهلات.
3. `core/auth/`: تسجيل الدخول والخروج وتجديد الجلسة.
4. `core/permissions/`: عرض الإجراءات بحسب الصلاحيات المعلنة من الخادم؛ الخادم يظل صاحب القرار النهائي.
5. `core/storage/`: تخزين أسرار الجلسة عبر مخزن آمن مناسب لكل منصة.
6. `design_system/`: مكونات الإدارة المشتركة، الجداول، النماذج، الفلاتر، الحالات الفارغة ورسائل الأخطاء.
7. `features/`: وحدات مستقلة؛ كل وحدة تحتوي واجهة وحالة وخدمات ونماذج واختبارات.

## مبادئ إلزامية

- لا نسخ بصري من الموقع أو لوحة الإدارة القديمة أو تطبيق الطلاب. نظام التصميم في `lib/src/design_system/` مستقل وأصيل؛ ملفات واجهة الموقع القديمة حُذفت من المستودع المستقل حتى لا تتحول إلى مرجع بصري ضمني.
- لا أسرار أو بيانات اعتماد ثابتة داخل المستودع أو التطبيق.
- لا اعتبار لأي عملية مكتملة قبل وجود واجهة فعلية، واتصال API صحيح، ومعالجة أخطاء، واختبار.
- لا تغيير في Backend أو ترحيل بيانات قبل اعتماد عقد التكامل وخطة التوافق.
- كل عمليات الكتابة يجب أن تخضع للتحقق والصلاحيات من جهة الخادم.
- تُختبر المنصات كلٌ في بيئتها المناسبة؛ بناء iOS والتوقيع يتطلب macOS/Xcode، وبناء Windows يتطلب Windows وأدوات Visual Studio المناسبة.

## نقاط لم تُحسم بعد

- هل سيستخدم الإصدار الأول Worker الحالي مباشرة، أم واجهة توافق إلى المعمارية المستهدفة؟
- خريطة الأدوار: يحتوي Backend الحالي على `super_admin` و`content_manager` و`academic_manager` و`moderator`. يجب اعتماد الأسماء النهائية وسياسة تحويل الأدوار قبل إخفاء الوحدات أو السماح بها في الواجهة.
- آلية توزيع نسخة iOS محليًا: أجهزة مسجلة/توقيع تطوير/توزيع مؤسسي وفق حساب Apple المتاح.


## Current role and usage-metrics update (2026-10-14)
The staff `moderator` role has been retired from the assignable admin role map and no longer receives privileged API permissions. Student moderation is an independent `students.is_moderator` flag controlled from TRINEX-Admin's Students page; the Worker enforces it for cross-user comment, reply and public-chat message deletion. The separate moderation page is no longer part of admin navigation.

Usage analytics now include aggregate route-level Worker request counts/duration/errors, executed D1 operations and available row metadata, and instrumented R2 operations/bytes. These application-side measurements do not equal Cloudflare billing or Worker CPU time.


## Current role and usage-metrics update (2026-10-14)
The staff `moderator` role has been retired from the assignable admin role map and no longer receives privileged API permissions. Student moderation is an independent `students.is_moderator` flag controlled from TRINEX-Admin's Students page; the Worker enforces it for cross-user comment, reply and public-chat message deletion. The separate moderation page is no longer part of admin navigation.

Usage analytics now include aggregate route-level Worker request counts/duration/errors, executed D1 operations and available row metadata, and instrumented R2 operations/bytes. These application-side measurements do not equal Cloudflare billing or Worker CPU time.

# TRINEX V2.0.0 — UI Pass 2

## الهدف
رفع جودة Flutter من Foundation/UI Pass 1 إلى طبقة UX أكثر قربًا من التصميم المرجعي، مع منع الخدمات الدراسية من بدء الشبكة قبل التحقق من الجلسة.

## ما تم تنفيذه
- حماية `/materials`, `/schedule`, `/notifications`, `/progress`, `/xp`, `/badges` عبر `StudentAccessGate` على مستوى الـrouter.
- الزائر يرى شاشة قفل واضحة وزر تسجيل الدخول بدل انتظار 401 من الـAPI.
- إزالة النص العربي الثابت من ContentList ونقله إلى Localization.
- إضافة مفاتيح AR/EN/FR لخدمات الطالب والبحث في المواد وقيمة XP.
- إضافة `ListSkeleton` واستخدامه في حالات تحميل Materials/Schedule/Notifications.
- تحسين Materials بإضافة بحث محلي عن المواد/الملفات.
- تحسين Schedule بإظهار الوقت داخل بطاقة واضحة وتحسين الـresponsive width.
- إصلاح Refresh في Schedule ليحفظ وينتظر الـFuture نفسه الذي أنشأه.
- إصلاح Refresh في ContentList بنفس النمط.
- إصلاح مفتاح Localization المفقود بعد `marketPlanStudent`.
- اختبار parity لمفاتيح Localization: 200 مفتاحًا في كل لغة، دون تكرار.
- تحديث Widget Test ليستخدم `MediaQueryData(disableAnimations: true)` بدل محاولة settle لحلقات animation غير منتهية.

## قواعد V2 المستمرة
- لا بيانات سوق وهمية.
- لا نصوص واجهة hard-coded.
- لا طلب شبكة لخدمة محمية قبل التحقق من الجلسة.
- لا تغيير للإصدار خارج `VERSION`.

## التحقق
بيئة التنفيذ الحالية لا تحتوي Flutter/Dart SDK، لذلك لا يتم الادعاء بأن `flutter analyze` أو `flutter test` تم تشغيلهما هنا. تم إجراء فحوصات static للملفات المعدلة، parity للـlocalization، وفحص بنيوي للأقواس، وفحص Python لأداة مزامنة الإصدار.

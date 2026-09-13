# خطة TRINEX V2.0.0 — Flutter

## الهدف
إعادة بناء تجربة Flutter فوق الأساس العامل الحالي، مع اعتماد هوية TRINEX المرفقة، دعم العربية والإنجليزية والفرنسية، محتوى ديناميكي من API/Dashboard، وأنيميشن حقيقية مرتبطة بدورة حياة التطبيق.

## قواعد V2
- رقم الإصدار يُغيّر في `flutter/VERSION` فقط.
- لا توجد نصوص واجهة ثابتة داخل الشاشات؛ كل النصوص عبر localization.
- البيانات التشغيلية لا تُدفن داخل Flutter؛ مصدرها API/Dashboard.
- كل شاشة تدعم حالات `loading / success / empty / error`.
- الحركات التجميلية لا تتحكم في اكتمال startup ولا تمنع الاختبارات من الاستقرار.
- دعم `disableAnimations` وتقليل الحركة عند طلب النظام.
- الحفاظ على API/repositories السليمة بدل إعادة بناء الـbackend.

## المرحلة المنفذة في هذه الدفعة
- نقل Flutter إلى `2.0.0+1`.
- إصلاح سكربت مزامنة الإصدار الذي كان يكتب `\\n` حرفيًا داخل `app_version.dart`.
- تسجيل route `/more`.
- تمرير startup update check كخيار قابل للتعطيل في اختبارات widget.
- جعل رسائل update الأساسية قابلة للترجمة.
- توسيع localization إلى أجزاء Home/More/Materials.
- إضافة interpolation للنصوص مثل رقم الإصدار وعدد الملفات.
- تحسين اختيار اللغة: العربية/English/Français/تلقائي.
- احترام `disableAnimations` في نبضة زر Eino.
- تخزين Future الفصول في Materials لتجنب طلب semesters مع كل rebuild.
- فتح رابط المادة فعليًا عبر النظام بدل عرضه كرابط نصي فقط.

## المرحلة التالية
1. استكمال localization لكل الشاشات.
2. تحويل Models/DTOs المتبقية إلى طبقة بيانات typed.
3. Auth Gate للمواد والجدول والتقدم.
4. إعادة بناء Design System وفق المرجع البصري.
5. Splash حقيقي مرتبط بالـstartup lifecycle.
6. Skeleton/Shimmer لكل مسارات التحميل.
7. Home V2 المطابق للمرجع.
8. Materials V2 وفتح الملفات/صفحة التفاصيل.
9. Schedule V2 مع caching ومنع rebuild requests.
10. Student/XP/Progress/Badges.
11. Notifications.
12. Eino Character System.
13. Student Guide.
14. More/Settings.
15. Marketplace ديناميكي أو إخفاؤه حتى يصبح API حقيقيًا.
16. responsive/accessibility/performance.
17. اختبارات routing/localization/auth/loading/animations.
18. Release V2.0.0.

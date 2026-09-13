# TRINEX V2.0.0 RC — CI Fix 01

تم إصلاح أول مجموعة أخطاء ظهرت من `flutter analyze` في GitHub Actions:

- إصلاح تعارض اسم `context` داخل Eino وإرسال BuildContext بشكل صريح.
- إضافة استيراد Design Tokens للشاشات التي تستخدم `AppColors`.
- إزالة استخدام `BuildContext` عبر async gaps في فتح المواد وتسجيل الدخول.
- تنظيف null-aware operators غير الضرورية في Schedule.
- إضافة الأقواس المطلوبة في حلقات Splash.
- جعل رسم دوائر Splash يتحدث فعليًا مع AnimationController بدل أن يبقى على أول frame.
- جعل StudentAccessGate يعتمد على `AuthStorage` بدل تكرار مفتاح الجلسة في مكان آخر.
- جعل تهيئة Eino آمنة عند التخلص من الشاشة أثناء انتظار إنشاء العميل.

ملاحظة: بيئة بناء هذه النسخة هنا لا تحتوي Flutter SDK، لذلك التحقق النهائي يتم عبر GitHub Actions.

# TRINEX V2.0.0 — RC Checklist

## Flutter

- [x] `VERSION` هو مصدر الإصدار الوحيد (`2.0.0+1`).
- [x] `AppVersion` مولّد من `VERSION`.
- [x] `/more` route موجود.
- [x] Student Access Gate للخدمات الدراسية.
- [x] فتح روابط المواد فعليًا.
- [x] Marketplace لا يعرض بيانات وهمية.
- [x] AR / EN / FR متطابقة في مفاتيح الترجمة.
- [x] اللغة التلقائية من الجهاز + لغة ثابتة من Settings.
- [x] Skeleton/Loading components.
- [x] Eino يحترم `disableAnimations`.
- [x] Splash مرتبط بتهيئة preferences الفعلية.
- [x] اختبار startup لا يستخدم `pumpAndSettle()` مع loops.

## يجب على CI تنفيذها

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

> لا تعتبر V2.0.0 Release Candidate نهائيًا حتى تمر أوامر CI الأربعة بنجاح.

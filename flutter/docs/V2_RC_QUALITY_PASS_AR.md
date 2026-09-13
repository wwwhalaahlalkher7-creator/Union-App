# TRINEX V2.0.0 — Release Candidate Quality Pass

تم تنفيذ مراجعة جودة نهائية على طبقة Flutter فوق نسخة V2 الحالية.

## ما تم تثبيته

- الإصدار الوحيد المصدر: `VERSION`.
- `AppVersion` مولّد من `VERSION` ولا يحتوي أرقام إصدار يدوية.
- `VERSION` الحالي: `2.0.0+1`.
- المسار `/more` مسجل فعليًا.
- الخدمات الدراسية محمية بـ Student Access Gate قبل طلب البيانات.
- فتح ملفات المواد يتم عبر `url_launcher` عند توفر رابط صالح.
- Marketplace لا يعرض بيانات وهمية قبل توفر عقد API/Dashboard.
- AR/EN/FR موجودة مع fallback واضح.
- اختيار اللغة يدعم لغة الجهاز أو لغة ثابتة من Settings.
- Eino وواجهات التحميل تحترم `disableAnimations` عبر `TickerMode` حيث يلزم.
- اختبار startup لا يعتمد على `pumpAndSettle()` مع animations دورية.
- Splash لا يستخدم انتظارًا شبكيًا مصطنعًا؛ ينتظر تهيئة preferences الفعلية مع مدة بصرية قصيرة لضمان ظهور الهوية.

## ملاحظات ما قبل النشر

هذه البيئة لا تحتوي Flutter SDK، لذلك يجب أن يكون CI هو المرجع النهائي لتشغيل:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

ولا يُرفع V2.0.0 إلى الإنتاج قبل نجاح هذه الخطوات.

# المرحلة الخامسة — Flutter Secure Storage

## الهدف

منع تخزين رموز جلسة الطالب (`access token` و`refresh token`) وبيانات ملف الجلسة في `SharedPreferences` غير المخصص للأسرار.

## التغييرات

- إضافة `flutter_secure_storage` بإصدار `^11.1.1`.
- نقل access/refresh tokens إلى التخزين الآمن للمنصة.
- نقل ملف الطالب المخزن محليًا إلى التخزين الآمن أيضًا.
- إضافة `AuthStorage.create()` لتهيئة التخزين وتنفيذ الترحيل مرة واحدة.
- ترحيل القيم القديمة من `SharedPreferences` إلى التخزين الآمن ثم حذف النسخ القديمة.
- تحويل قراءات حالة الجلسة والرموز إلى عمليات `async` بما يتوافق مع secure storage.
- الحفاظ على آلية refresh الحالية عند استجابة `401`، مع قراءة refresh token من التخزين الآمن.
- إبقاء `SharedPreferences` للاعدادات العامة فقط؛ لا يستخدم لحفظ أسرار المصادقة.

## التحقق

تم تشغيل:

```text
FLUTTER SECURE STORAGE CHECK PASSED
```

يتطلب التحقق النهائي تشغيل `flutter pub get` و`flutter analyze` و`flutter test` في بيئة Flutter الفعلية، لأن Flutter SDK غير متوفر في بيئة تجهيز الأرشيف.

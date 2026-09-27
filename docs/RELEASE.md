# Release Process

## المصدر الوحيد للإصدار

الملف الوحيد الذي نعدله يدويًا للإصدار هو:

`flutter/VERSION`

الصيغة:

```text
MAJOR.MINOR.PATCH+BUILD
# Release notes written here become the release notes automatically.
```

مثال:

```text
2.0.1+3
# إصلاحات وتحسينات في التحقق من التحديثات.
```

من هذا الملف يتم توليد تلقائيًا:

- Flutter/Android version name = `2.0.1`
- Android build number = `3`
- Backend `APP_VERSION = 2.0.1`
- Backend `APP_RELEASE_NOTES` من التعليقات
- GitHub tag = `v2.0.1`
- GitHub Release = `Union App v2.0.1`

## الإصدار التلقائي

عند دمج تغيير `flutter/VERSION` إلى `main`:

1. يتم تشغيل بوابة الإصدار.
2. يتم بناء APK وAAB واختبارهما.
3. يتم نشر الـ backend بالقيم المستخرجة من `flutter/VERSION`.
4. ينتظر نشر الموقع حتى يصبح APK الجديد جاهزًا.
5. يتم وضع أحدث APK داخل `dist/downloads/` ليُنشر مع الموقع.
6. يتم نشر الموقع.
7. يتم إنشاء Tag وGitHub Release تلقائيًا إذا لم يكونا موجودين.

إذا كان الإصدار نفسه منشورًا بالفعل، لا يتم إنشاء Release مكرر.

## سياسة التحديث داخل التطبيق

المقارنة بين الإصدارات تعتمد على `MAJOR.MINOR.PATCH` فقط، ولا تستخدم رقم البناء `+BUILD` لاكتشاف إصدار جديد.

رابط التحديث يبقى حاليًا فارغًا (`APP_UPDATE_URL = ""`). عند تجهيز صفحة التحميل الثابتة لاحقًا، نضع رابط الصفحة مرة واحدة في إعدادات الإنتاج، وتبقى الصفحة ثابتة بينما يتغير ملف APK المنشور خلفها.

## Release checklist

- [ ] تعديل `flutter/VERSION` فقط.
- [ ] كتابة ملاحظات الإصدار بعد `#` عند الحاجة.
- [ ] CI على `main` ناجح.
- [ ] production signing secrets متاحة داخل GitHub Environment باسم `production`.
- [ ] health/version بعد النشر مطابقان للنسخة المتوقعة.
- [ ] لا توجد secrets أو ملفات build حساسة في Git.

## GitHub Release

الـ Release الرسمي يحتوي فقط على:

- `Union-App-vX.Y.Z.apk`
- `Union-App-vX.Y.Z.aab`
- `SHA256SUMS.txt`

GitHub يوفر source archives تلقائيًا للـ tag، لذلك لا نضيف source zip إضافيًا.

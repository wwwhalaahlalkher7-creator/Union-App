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
2.0.2+1
# ملاحظات الإصدار الحالية تُستخرج تلقائيًا من flutter/VERSION.
```

من هذا الملف يتم توليد تلقائيًا:

- Flutter/Android version name = `2.0.2`
- Android build number = `1`
- Backend `APP_VERSION = 2.0.2`
- Backend `APP_RELEASE_NOTES` من التعليقات
- GitHub tag = `v2.0.2`
- GitHub Release = `TRINEX v2.0.2`

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

رابط التحديث الحالي هو `https://ush-eng.great-site.net/download.html`، وتبقى صفحة التحميل ثابتة بينما يتغير ملف APK المنشور خلفها.

## Release checklist

- [ ] تعديل `flutter/VERSION` فقط.
- [ ] كتابة ملاحظات الإصدار بعد `#` عند الحاجة.
- [ ] CI على `main` ناجح.
- [ ] production signing secrets متاحة داخل GitHub Environment باسم `production`.
- [ ] health/version بعد النشر مطابقان للنسخة المتوقعة.
- [ ] لا توجد secrets أو ملفات build حساسة في Git.

## GitHub Release

الـ Release الرسمي يحتوي على:

- `TRINEX.apk` — ملف APK الرسمي الذي يستخدمه رابط التنزيل الثابت.
- `TRINEX.zip` — نسخة مضغوطة من نفس `TRINEX.apk` محفوظة داخل الـTag/Release.
- `SHA256SUMS.txt` — بصمات SHA-256 للملفين.

GitHub يوفر source archives تلقائيًا للـ tag، لذلك لا نضيف source zip إضافيًا.

# Release Process

## مصدر الإصدار

المصدر الوحيد لنسخة Flutter:

`flutter/VERSION`

الصيغة:

```text
MAJOR.MINOR.PATCH+BUILD
```

بعد تعديلها:

```bash
cd flutter
python3 tool/sync_version.py
```

ثم تحقق من:

```bash
python3 ../ci/verify_project.py
python3 ../ci/release_check.py
```

## Release checklist

- [ ] `flutter/VERSION` صحيح.
- [ ] `pubspec.yaml` و`app_version.dart` متزامنان.
- [ ] `applicationId` بقي `com.leoassociation.app`.
- [ ] أي migration جديدة تعمل بالتسلسل.
- [ ] contract/security checks ناجحة.
- [ ] `flutter analyze` ناجح.
- [ ] `flutter test` ناجح.
- [ ] `flutter build apk --release` ناجح.
- [ ] `flutter build appbundle --release` ناجح.
- [ ] production signing secrets متاحة على `main`.
- [ ] health/version بعد النشر مطابقان للنسخة المتوقعة.
- [ ] لا توجد secrets أو ملفات build حساسة في Git.

## سياسة versioning

- **Patch:** إصلاح bug دون تغيير contract.
- **Minor:** ميزة متوافقة للخلف.
- **Major:** تغيير contract أو architecture يحتاج تنسيقًا واسعًا.
- **Build:** رقم Android المتزايد لكل artifact قابل للتوزيع.

## بعد الإصدار

لا تكتب `STAGE_*` أو `README_STAGE*` جديدًا. إذا تغير behavior، حدّث `CHANGELOG.md` ووثيقة التشغيل المتأثرة فقط.

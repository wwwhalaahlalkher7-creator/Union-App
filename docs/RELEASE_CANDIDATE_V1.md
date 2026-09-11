# Release Candidate — رابطة كلية الهندسة والعمارة

## الإصدار

**2.6.0+17**

هذا الإصدار هو **Release Candidate**: لا تتم إضافة ميزات مستخدم جديدة بعد هذه النقطة. أي تغيير لاحق يجب أن يكون إصلاحًا، أمانًا، أداءً، توافقًا، أو مانعًا للإصدار.

## ما تم تثبيته

- مصدر النسخة الوحيد: `flutter/VERSION`.
- Android Application ID ثابت: `com.leoassociation.app`.
- `versionCode` و`versionName` مرتبطان بمصدر النسخة المركزي.
- جميع migrations من `0001` إلى `0013` تُطبّق بالتسلسل في اختبار SQLite.
- فحص Worker/backend وDashboard JavaScript جزء من CI.
- فحص سياسة المصدر يمنع إعادة إدخال Apps Script/Airtable التشغيلي أو نظام الإعلانات التجاري القديم.
- Dashboard هو مركز التشغيل للمحتوى والبيانات الإدارية؛ لا توجد عودة للتعديل اليدوي لمجرد النشر.
- Association API هي بوابة التطبيق وDashboard، وEino يمر عبرها إلى Leo-OmniRoute.

## الهوية والتحديث فوق النسخة القديمة

للحفاظ على إمكانية التحديث فوق النسخة السابقة يجب أن يبقى:

1. `applicationId` كما هو: `com.leoassociation.app`.
2. مفتاح توقيع الإنتاج نفسه المستخدم للنسخة المثبتة على الجهاز.
3. `versionCode` أعلى من النسخة المثبتة.

**مهم:** بيئة المشروع الحالية لا تحتوي على مفتاح الإنتاج. إعداد Gradle الحالي يستخدم debug signing فقط لبناء artifact قابل للتثبيت والاختبار في CI. لذلك لا يعتبر هذا الملف تصريحًا بأن APK/AAB موقّع للإنتاج أو جاهز لـ Google Play.

## بوابة القبول

### آلي

- [x] Centralized version check
- [x] Android identity check
- [x] Sequential D1 migration smoke test
- [x] Backend syntax check عبر CI
- [x] Dashboard JavaScript syntax check عبر CI
- [x] Legacy/commercial source-policy scan
- [x] CI workflow موجود ويشغّل analyze/test/build
- [x] ZIP integrity

### يحتاج بيئة CI/إصدار حقيقية

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build apk --release`
- [ ] `flutter build appbundle --release`
- [ ] اختبار تثبيت RC فوق نسخة سابقة بنفس signing key
- [ ] إعداد release keystore الحقيقي
- [ ] اختبار Worker/D1 على بيئة الإنتاج بعد توفير credentials وD1 database ID

## ممنوع في RC

- إعادة نظام الإعلانات التجاري.
- إعادة Apps Script/Airtable كطبقة تشغيل.
- إضافة محتوى تشغيلي داخل الكود بدل Dashboard.
- تغيير Application ID.
- استخدام مفتاح توقيع مختلف لنسخة التحديث.
- إضافة ميزات كبيرة جديدة بدون فتح مرحلة جديدة.

# سياسة الإصدار — رابطة كلية الهندسة والعمارة

## الإصدار الحالي

`2.6.0+17` — Release Candidate

المصدر الوحيد للنسخة هو `flutter/VERSION`. استخدم `python3 flutter/tool/sync_version.py` عند تغييرها، ثم شغّل فحوص CI.

## الهوية

- Android Application ID: `com.leoassociation.app`
- `versionCode`: مأخوذ من `flutter/VERSION`
- `versionName`: مأخوذ من `flutter/VERSION`

للتحديث فوق نسخة مثبتة يجب استخدام **نفس مفتاح توقيع الإنتاج** مع `versionCode` أعلى. مفتاح الإنتاج ليس مضمنًا في المستودع.

## RC مقابل Production

الـ CI الحالي يبني release artifact قابلًا للتثبيت باستخدام debug signing للاختبار. هذا لا يساوي توقيع إنتاج.

قبل النشر العام يجب توفير keystore الإنتاج في بيئة أسرار CI/النشر، ثم التحقق من تثبيت التحديث فوق النسخة السابقة بنفس المفتاح.

## البنية التشغيلية

Flutter وDashboard لا يتصلان مباشرة بمصادر البيانات القديمة. المسار المعتمد:

`Flutter / Dashboard → Association API → D1 / Drive / Notifications / Eino → Leo-OmniRoute`

لا يُعاد تفعيل Apps Script/Airtable كطبقة تشغيل، ولا نظام الإعلانات التجاري.

## محتوى التشغيل

الأخبار والإعلانات والمواد والجداول والطلاب والشارات والصلاحيات تُدار من Dashboard/API، وليس بتعديل ملفات الكود أو بيانات تشغيلية يدويًا.

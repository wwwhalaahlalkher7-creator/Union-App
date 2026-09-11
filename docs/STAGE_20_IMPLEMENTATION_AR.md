# المرحلة 20 — نظام الإصدار المركزي

## الهدف
جعل رقم إصدار التطبيق موحّدًا ومراجَعًا من مصدر واحد، ومنع اختلاف نسخة Flutter عن نسخة API.

## مصدر الحقيقة
`flutter/VERSION`

الصيغة:
`MAJOR.MINOR.PATCH+BUILD`

## الملفات المولدة/المزامنة
- `flutter/pubspec.yaml`
- `flutter/lib/core/app_version.dart`

يتم تشغيل:
`python3 tool/sync_version.py`

## API
تمت إضافة:
`GET /api/v1/version`

ويعيد:
- `appVersion`
- `minimumAppVersion`
- `apiVersion`

كما تم توحيد `APP_VERSION` في Worker.

## حدود المرحلة
هذه المرحلة تؤسس نظام الإصدار فقط. آلية التحديث الإجباري/الاختياري وتوافق النسخ تأتي في المرحلة 21.

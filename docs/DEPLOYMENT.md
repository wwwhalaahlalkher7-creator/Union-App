# Deployment Runbook

## المسار الطبيعي

```text
push main / Pull Request
   ├── Flutter-related changes → Flutter CI → analyze/test → signed APK/AAB → compressed `TRINEX APK.zip` + `TRINEX AAB.zip` artifacts
   ├── Backend-related changes → Backend CI → validate → deploy Worker + D1 on main
   └── Website-related changes → Website CI → build/security → deploy to InfinityFree on main

manual Production App Release
   └── Signed APK → GitHub Release → stable download asset `TRINEX.apk` plus compressed release backup `TRINEX.zip`
```

## Backend

Workflow: `.github/workflows/ci.yml` (job: `backend`)

يعمل عند تغيّر ملفات الـBackend ذات الصلة. على Pull Request يكتفي بالتحقق وdry-run، وعلى `main` ينفذ النشر إلى Cloudflare Worker وتطبيق D1 migrations ومزامنة الأسرار المطلوبة.

## Flutter

Workflow: `.github/workflows/ci.yml` (job: `flutter`)

يعمل عند تغيّر ملفات Flutter ذات الصلة، ويشغّل analyze/test ويبني **APK وAAB موقّعين فعليًا** ويضعهما في ملفين مضغوطين `TRINEX APK.zip` و`TRINEX AAB.zip` كـArtifacts للاختبار. تستخدم هذه النسخ نفس آلية Android release signing، لكنها ليست Release منشورًا.

الإصدار الرسمي للتطبيق منفصل في `.github/workflows/release.yml` ويُشغّل يدويًا فقط.

## Production App Release

Workflow: `.github/workflows/release.yml`

يقرأ `flutter/VERSION`، يتحقق من version/build، ثم يبني APK وAAB موقّعين بمفتاح الإنتاج وينشرهما في GitHub Releases. الملف الرسمي الذي يستهدفه زر التنزيل اسمه دائمًا `TRINEX.apk`، وتُحفظ معه نسخة مضغوطة `TRINEX.zip`.

رابط التنزيل الثابت في الموقع هو:

```text
https://github.com/wwwhalaahlalkher7-creator/Union-App/releases/latest/download/TRINEX.apk
```

هذا الـworkflow لا ينشر الموقع ولا الـBackend.

## Website

Workflow: `.github/workflows/ci.yml` (job: `website`)

يتحقق من JavaScript والملفات المطلوبة وسياسة المصادر القديمة، ثم ينشر `dist/` إلى InfinityFree عبر FTPS عند تغيّر ملفات الموقع على `main`.

صفحة تحميل التطبيق لا تعتمد على `release.json` مستضاف على InfinityFree؛ زر التنزيل مرتبط مباشرةً بأحدث GitHub Release Asset.

## تحقق بعد النشر

### API

```text
GET /api/v1/health
GET /api/v1/version
```

تحقق من:

- `status` في health.
- اتصال D1.
- `apiVersion`.
- `appVersion` و`minimumAppVersion`.

### Website

تحقق من:

- الصفحة الرئيسية.
- `/admin/`.
- تسجيل دخول الإدارة.
- تحميل المحتوى من API.
- زر تنزيل التطبيق وأنه يشير إلى GitHub Releases.

### Eino

اختبر طلبًا عاديًا من التطبيق، ثم راقب `admin/security/eino-usage` إذا كان لديك صلاحية الإدارة.

## Rollback

لا تعكس migration بإعادة تسمية أو حذف الملف. عند وجود migration خاطئة، أنشئ migration تصحيحية.

للتطبيق/الموقع، استخدم Git commit معروفًا ثم أعد النشر بعد التأكد من توافق D1/API.

## Signing

لا يتم تضمين keystore في المستودع. تحديث Android فوق نسخة منشورة يتطلب نفس مفتاح توقيع الإنتاج و`versionCode` أعلى.

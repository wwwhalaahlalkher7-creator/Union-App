# Changelog

## 2026-09-27 — Release Infrastructure Polish

- فصل CI عن Production Release في GitHub Actions.
- تجهيز GitHub Releases رسمية تحتوي على APK وAAB وSHA-256 checksums فقط.
- إضافة `.env.example` حقيقي كمرجع للإعدادات المحلية، مع `backend/.dev.vars.example` لأسرار Wrangler المحلية.
- إضافة قواعد Git وEditorConfig وDependabot وقالب Pull Request وسياسة Security.
- توحيد إصدار Worker مع إصدار التطبيق الحالي `2.0.0`.


## Backend Hardening — 2026-09-22

- Added migration `0024_relationship_indexes.sql` with domain-aligned relationship/query indexes.
- Preserved historical migration files; no existing table was renamed or dropped.
- Added a canonical database schema map in `docs/DATABASE_SCHEMA.md`.
- Added a SQLite-backed backend schema audit to CI.
- Made student/staff failed-login counters atomic to avoid concurrent read/write races.
- Converted bulk notification read updates from one query per notification to one set-based update.
- Kept historical-semester material browsing available, including archived semesters, while constraining access to the student's department.
- Retained the intentional Google Drive deletion coupling.
# Changelog

## 2026-09-15 — Maintenance Baseline

- توحيد الوثائق التشغيلية في `docs/`.
- حذف وثائق المراحل القديمة وREADME المرحلية المتكررة.
- توثيق Source of Truth والمعمارية الحالية.
- توحيد دليل الإعداد والأسرار والنشر والإصدار والصيانة.
- إزالة اعتماد فحص CI على وثائق مرحلة تاريخية.
- تصحيح سياسة فحص legacy references لتمييز Google Apps Script الحالي كـDrive adapter عن تكاملات التشغيل القديمة.

> التاريخ التفصيلي للميزات السابقة محفوظ في Git history بدل ملفات Stage داخل المستودع.

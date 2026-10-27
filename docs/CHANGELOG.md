# Changelog

## 2026-10-27 — TRINEX Drive Library Reconciliation (Implementation Batch 1)

- جعل هوية مجلد المادة مرتبطة بمعرّف Google Drive الثابت حتى لا يؤدي تغيير الاسم إلى إنشاء مادة مكررة في D1.
- فهرسة مجلدات المواد الفارغة، ومزامنة أسماء مجلدات المواد وملفات PDF مع D1.
- استكمال عمليات إنشاء مجلد مادة، وإعادة تسمية المجلد والملف، ورفع PDF، وحذف مجلد المادة من لوحة الإدارة عبر Google Apps Script.
- منع تعطيل عناصر D1 عند اكتشاف فهرس Drive غير مكتمل أو غير قابل للربط؛ حمايةً من الحذف الجماعي الناتج عن مزامنة ناقصة.
- جعل صفحة إدارة المواد تجلب جميع صفحات المواد والمجلدات بدل الاقتصار على أول 100 سجل.
- استبدال شريط عدم الاتصال بمؤشر Wi-Fi صغير يعرض حالتي الاتصال والانقطاع.
- إضافة مركز دراسة شخصي داخل صفحة الملف الشخصي فقط، مع روابط التقدم الدراسي والأدوات الهندسية والإشعارات.
- لم يُغيّر نموذج الامتحانات ولم تُضف إدارة الامتحانات إلى لوحة التحكم.


## 2026-09-29 — Maintenance & Architecture Cleanup

- فصل Worker router عن منطق الـAPI إلى modules حسب النطاق تحت `services/api/src/`.
- تحديث فحوصات CI لتفهم البنية المعيارية الجديدة.
- حذف `dist/` والوثائق المرحلية/المكررة والملفات Flutter غير المستخدمة.
- توحيد توثيق بنية الموقع ولوحة الإدارة مع المسارات الحالية.

## 2026-09-27 — Release Infrastructure Polish

- فصل CI عن Production Release في GitHub Actions.
- تجهيز GitHub Releases رسمية تحتوي على APK وAAB وSHA-256 checksums فقط.
- إضافة `.env.example` حقيقي كمرجع للإعدادات المحلية، مع `services/api/.dev.vars.example` لأسرار Wrangler المحلية.
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
## 2026-09-15 — Maintenance Baseline

- توحيد الوثائق التشغيلية في `docs/`.
- حذف وثائق المراحل القديمة وREADME المرحلية المتكررة.
- توثيق Source of Truth والمعمارية الحالية.
- توحيد دليل الإعداد والأسرار والنشر والإصدار والصيانة.
- إزالة اعتماد فحص CI على وثائق مرحلة تاريخية.
- تصحيح سياسة فحص legacy references لتمييز Google Apps Script الحالي كـDrive adapter عن تكاملات التشغيل القديمة.

> التاريخ التفصيلي للميزات السابقة محفوظ في Git history بدل ملفات Stage داخل المستودع.

## Batch 12 — Eino retrieval confidence and exam administration
- Added confidence-aware filtering to Eino lexical retrieval to reduce weak partial matches when stronger chunks are available.
- Added an Arabic admin exam library page aligned with the department → semester → subject hierarchy. First upload creates the `exams` folder automatically; staff can rename/delete PDFs.
- Added an Apps Script exam index and guarded Worker endpoints for exam operations, with audit entries. Exam PDFs under the dedicated folder are excluded from the regular study-material reconciliation.
- No D1 schema migration and no student-side exam model/UI changes.

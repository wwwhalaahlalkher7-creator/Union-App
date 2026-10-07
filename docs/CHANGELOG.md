# Changelog

## 2026-10-07 — TRINEX 2.0.2+1

- إصدار متكامل لمنصة TRINEX للطلاب، يجمع المحتوى الأكاديمي والخدمات الجامعية والتفاعل والمساعدة الذكية في تجربة واحدة.
- تحسين تسجيل الدخول والحساب الشخصي وإدارة الملف وتغيير كلمة المرور واستعادتها عبر البريد الإلكتروني مع تخزين آمن للجلسة.
- دعم الأخبار والإنجازات والفعاليات والوسائط والتفاصيل والتعليقات والإشعارات.
- تنظيم المواد الدراسية حسب التخصص والفصل، مع عرض الملفات وقراءة PDF والوصول الآمن إلى المحتوى السابق المتاح.
- الجدول الدراسي والأدوات الهندسية، بما فيها محول الوحدات وحاسبة GPA وحاسبة المقاومات والمراجع الهندسية.
- المفضلة والمحتوى الأخير والتقدم وXP والشارات والأحداث التعليمية ضمن تجربة الطالب.
- دمج Eino كمساعد ذكي عبر طبقة API آمنة، مع أساس محلي للنماذج ودعم fallback عند تعذر الاتصال بالمسار الأساسي.
- تحسين وضع عدم الاتصال والتخزين المؤقت: محاولة الشبكة أولاً، ثم استخدام البيانات المخزنة عند الحاجة، مع رسائل أخطاء واضحة للمستخدم.
- دعم الموقع العام ولوحة الإدارة وإدارة المحتوى والطلاب والصلاحيات والتعليقات والإشعارات.
- فصل تكاملات TRINEX Drive وTRINEX Gmail، وتحسين طبقة Cloudflare Workers وD1.
- إعادة تنظيم كبيرة للكود وفق Clean Code وDependency Injection وفصل طبقات الشبكة والـrepositories والواجهات، مع تقليل التكرار وتحسين قابلية الصيانة.
- تعزيزات أمنية للمصادقة والتخزين الآمن والاستجابات وحماية الويب وXSS، مع فحوصات CI لعقود API وقاعدة البيانات والإصدار.

## 2026-09-29 — Maintenance & Architecture Cleanup

- فصل Worker router عن منطق الـAPI إلى modules حسب النطاق تحت `backend/src/`.
- تحديث فحوصات CI لتفهم البنية المعيارية الجديدة.
- حذف `dist/` والوثائق المرحلية/المكررة والملفات Flutter غير المستخدمة.
- توحيد توثيق بنية الموقع ولوحة الإدارة مع المسارات الحالية.

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
## 2026-09-15 — Maintenance Baseline

- توحيد الوثائق التشغيلية في `docs/`.
- حذف وثائق المراحل القديمة وREADME المرحلية المتكررة.
- توثيق Source of Truth والمعمارية الحالية.
- توحيد دليل الإعداد والأسرار والنشر والإصدار والصيانة.
- إزالة اعتماد فحص CI على وثائق مرحلة تاريخية.
- تصحيح سياسة فحص legacy references لتمييز Google Apps Script الحالي كـDrive adapter عن تكاملات التشغيل القديمة.

> التاريخ التفصيلي للميزات السابقة محفوظ في Git history بدل ملفات Stage داخل المستودع.

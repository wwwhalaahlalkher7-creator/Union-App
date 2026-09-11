# استيراد البيانات إلى D1 — المرحلة 4

صدّر البيانات الحالية إلى JSON داخل `data-import/input/` وفق القوالب. لا تضع مفاتيح Airtable/Google في المستودع.

الملفات: students, subjects, materials, schedules, news, activities, achievements, announcements.

التحقق ثم البناء:
```bash
cd backend
node scripts/validate-import.mjs data-import/input
node scripts/build-d1-import.mjs data-import/input data-import/out/import.sql
```

بعد المراجعة فقط:
```bash
npx wrangler d1 execute leo-association-db --remote --file=data-import/out/import.sql
```

لا يتم استيراد Ads. كلمات المرور/الأسرار لا تُستورد كنص صريح.

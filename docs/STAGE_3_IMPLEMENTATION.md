# المرحلة 3 — Association API

## المنجز
تمت إضافة Worker جديد في `backend/` ليكون نقطة الدخول الموحدة `/api/v1`.

### المسارات الأساسية
- `/health`
- `/public/news`
- `/public/announcements`
- `/public/activities`
- `/public/achievements`
- `/public/settings`
- `/auth/*`
- `/student/*`
- `/semesters`, `/departments`, `/subjects`
- `/materials`, `/schedule`
- `/progress`, `/xp`, `/badges`
- `/content/*/comments`, replies, reactions
- `/eino/chat`
- `/admin/*` boundary جاهز لكنه مقفول حتى إكمال Staff Auth

## قواعد حماية مهمة
- Flutter لا يتصل بـ Airtable أو Apps Script أو OmniRoute مباشرة.
- department للمواد يؤخذ من جلسة الطالب، وليس من قيمة يثق بها العميل.
- العميل لا يرسل قيمة XP النهائية.
- Eino لا يعمل دون أسرار Worker.
- لا يوجد commercial ads في التصميم الجديد؛ announcements هي البديل التشغيلي للرابطة.

## الخطوة التالية
إكمال Staff Auth + Dashboard authorization ثم نقل أول وحدة تشغيلية إلى D1، ويفضل أن تكون `Departments/Semesters/Subjects` لأنها أساس المواد والجدول.

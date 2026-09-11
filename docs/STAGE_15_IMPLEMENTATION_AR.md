# Stage 15 — التعليقات والردود والتفاعلات والإشراف

- Pagination للتعليقات والردود.
- حذف الطالب لتعليقه فقط.
- حدود معدل server-side: 10 تعليقًا/10 دقائق، 15 ردًا/10 دقائق، 40 تفاعلًا/10 دقائق.
- قائمة تفاعلات ثابتة: like / helpful / love / celebrate.
- منع أنواع المحتوى غير المدعومة.
- إشراف Dashboard للأدوار `moderator` و`super_admin`.
- حالات الإشراف: visible / hidden / deleted.
- سجل تدقيق عند تغيير الحالة.
- Flutter أضيفت له طبقة `InteractionsRepository` وعميل HTTP يدعم DELETE.
- لا توجد إعلانات تجارية في هذه الوحدة.

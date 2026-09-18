import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';

class ScheduleScreen extends StatefulWidget { const ScheduleScreen({super.key}); @override State<ScheduleScreen> createState() => _ScheduleScreenState(); }
class _ScheduleScreenState extends State<ScheduleScreen> {
  int selectedDay = 0;
  bool showWeek = false;
  final days = const ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  @override Widget build(BuildContext context) {
    final day = days[selectedDay];
    final items = MockData.schedule.where((e) => e.day == day).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(24, 22, 24, 100), children: [
      const _ScheduleHeader(),
      const SizedBox(height: 24),
      Container(height: 58, padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.border)), child: Row(children: [Expanded(child: GestureDetector(onTap: () => setState(() => showWeek = false), child: _Toggle('عرض اليوم', !showWeek))), Expanded(child: GestureDetector(onTap: () => setState(() => showWeek = true), child: _Toggle('عرض الأسبوع', showWeek)))])),
      const SizedBox(height: 22),
      SizedBox(height: 112, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: days.length, separatorBuilder: (_, _) => const SizedBox(width: 14), itemBuilder: (_, i) => GestureDetector(onTap: () => setState(() => selectedDay = i), child: Container(width: 150, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: i == selectedDay ? AppColors.cyan : AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: i == selectedDay ? AppColors.cyan : AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(days[i], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: i == selectedDay ? Colors.white : AppColors.text)), const SizedBox(height: 8), Text('${MockData.schedule.where((e) => e.day == days[i]).length} محاضرات', style: TextStyle(color: i == selectedDay ? Colors.white.withValues(alpha: .8) : AppColors.muted))]))))),
      const SizedBox(height: 24),
      if (showWeek)
        for (final weekDay in days) ...[
          Padding(padding: const EdgeInsets.only(bottom: 10, top: 4), child: Text(weekDay, textAlign: TextAlign.right, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
          for (final item in MockData.schedule.where((e) => e.day == weekDay)) Padding(padding: const EdgeInsets.only(bottom: 14), child: _Lecture(item: item)),
          if (MockData.schedule.every((e) => e.day != weekDay)) const Padding(padding: EdgeInsets.only(bottom: 14), child: Text('لا توجد محاضرات.', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted))),
        ]
      else if (items.isEmpty) Container(height: 300, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)), child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.event_busy_rounded, size: 64, color: AppColors.muted), SizedBox(height: 14), Text('لا توجد محاضرات مجدولة لهذا اليوم.', style: TextStyle(color: AppColors.muted, fontSize: 17))]))
      else for (final item in items) Padding(padding: const EdgeInsets.only(bottom: 14), child: _Lecture(item: item)),
      const SizedBox(height: 14),
      const Text('بيانات تجريبية محلية • سيتم استبدالها بجدول الطالب الفعلي بعد ربط Backend', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
    ]);
  }
}
class _ScheduleHeader extends StatelessWidget { const _ScheduleHeader(); @override Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Row(mainAxisAlignment: MainAxisAlignment.end, children: [Flexible(child: Text('الجدول الدراسي الأسبوعي', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),), SizedBox(width: 14), Icon(Icons.calendar_month_rounded, color: AppColors.cyan, size: 36)]), SizedBox(height: 7), Text('الهندسة • الفصل 8 (الفصل الدراسي المعتمد)', style: TextStyle(color: AppColors.muted, fontSize: 16))]); }
class _Toggle extends StatelessWidget { const _Toggle(this.label, this.selected); final String label; final bool selected; @override Widget build(BuildContext context) => Container(alignment: Alignment.center, decoration: BoxDecoration(color: selected ? AppColors.navy : Colors.transparent, borderRadius: BorderRadius.circular(24)), child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.muted))); }
class _Lecture extends StatelessWidget { const _Lecture({required this.item}); final MockLecture item; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 58, height: 58, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .14), borderRadius: BorderRadius.circular(17)), child: Icon(item.icon, color: Theme.of(context).colorScheme.primary, size: 29)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(item.subject, textAlign: TextAlign.right, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(item.room, style: const TextStyle(color: AppColors.muted))])), Text(item.time, style: const TextStyle(color: AppColors.cyan, fontSize: 20, fontWeight: FontWeight.w900))])); }

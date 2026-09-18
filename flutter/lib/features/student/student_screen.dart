import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';

class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key});
  @override Widget build(BuildContext context) {
    final s = MockData.student;
    return ListView(padding: const EdgeInsets.fromLTRB(24, 22, 24, 100), children: [
      Container(padding: const EdgeInsets.fromLTRB(24, 22, 24, 20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.border)), child: Column(children: [
        Container(width: 132, height: 132, padding: const EdgeInsets.all(5), decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [AppColors.cyan, AppColors.purple]), boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: .2), blurRadius: 28)]), child: ClipOval(child: Image.asset('assets/images/mock_student_avatar.jpg', fit: BoxFit.cover))),
        const SizedBox(height: 16), Text(s.name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(s.major, style: const TextStyle(color: AppColors.cyan, fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 14), _Pill(text: s.number), const SizedBox(height: 18), Wrap(alignment: WrapAlignment.center, spacing: 20, runSpacing: 10, children: [Text('المشرف: ${s.supervisor}', style: const TextStyle(color: AppColors.muted)), Text(s.email, style: const TextStyle(color: AppColors.muted)), const Text('•'), const Text('الحالة: طالب منتظم', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800))])
      ])),
      const SizedBox(height: 16),
      _StatCard(title: 'الفصل الدراسي', value: '${s.semester}', suffix: '/ ${s.totalSemesters} فصول', note: 'المستوى الأكاديمي الثالث', color: AppColors.cyan),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _ActionCard('مقررات الفصل', Icons.menu_book_rounded, AppColors.cyan, () => context.go('/materials'))), const SizedBox(width: 12), Expanded(child: _ActionCard('جدول المحاضرات', Icons.calendar_month_rounded, const Color(0xFF4E7BFF), () => context.go('/schedule'))), const SizedBox(width: 12), Expanded(child: _ActionCard('الشارات ونقاط XP', Icons.workspace_premium_rounded, AppColors.gold, () => context.go('/system')))]),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)), child: Row(children: [Expanded(child: FilledButton.icon(onPressed: () => context.go('/login'), icon: const Icon(Icons.logout_rounded), label: const Text('تسجيل الخروج'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5C1530), foregroundColor: const Color(0xFFFF8BA9), minimumSize: const Size.fromHeight(46)))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعديل الملف متاح بعد ربط الحساب — Mock Data'))), icon: const Icon(Icons.edit_outlined), label: const Text('تعديل الملف'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46))))])),
    ]);
  }
}
class _Pill extends StatelessWidget { const _Pill({required this.text}); final String text; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9), decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w700))); }
class _ActionCard extends StatelessWidget { const _ActionCard(this.title, this.icon, this.color, this.onTap); final String title; final IconData icon; final Color color; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Container(height: 88, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 26), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))])); }

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';

class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = MockData.student;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.cyan, AppColors.purple]),
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/mock_student_avatar.jpg', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 14),
              Text(student.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(student.major, style: const TextStyle(color: AppColors.cyan, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 11),
              _Pill(text: student.number),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 7,
                children: [
                  Text('المشرف: ${student.supervisor}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  Text(student.email, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const Text('الحالة: طالب منتظم', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SemesterCard(student: student),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _ActionCard('مقررات الفصل', Icons.menu_book_rounded, AppColors.cyan, () => context.go('/materials'))),
            const SizedBox(width: 9),
            Expanded(child: _ActionCard('جدول المحاضرات', Icons.calendar_month_rounded, const Color(0xFF4E7BFF), () => context.go('/schedule'))),
            const SizedBox(width: 9),
            Expanded(child: _ActionCard('الشارات وXP', Icons.workspace_premium_rounded, AppColors.gold, () => context.go('/system'))),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.logout_rounded, size: 19),
                  label: const Text('تسجيل الخروج'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5C1530),
                    foregroundColor: const Color(0xFFFF8BA9),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعديل الملف متاح بعد ربط الحساب')),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل الملف'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SemesterCard extends StatelessWidget {
  const _SemesterCard({required this.student});
  final MockStudent student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('الفصل الدراسي', style: TextStyle(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Text('${student.semester}', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.cyan)),
                Text('/ ${student.totalSemesters} فصول', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Container(width: 1, height: 58, color: AppColors.border),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('المستوى الأكاديمي', style: TextStyle(color: AppColors.muted, fontSize: 14)),
                const SizedBox(height: 8),
                Text(student.levelName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('المستوى ${student.level}', style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.title, this.icon, this.color, this.onTap);
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 76,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

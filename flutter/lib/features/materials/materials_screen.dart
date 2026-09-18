import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  String query = '';
  int selectedSemester = 8;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<MockMaterial>>{};
    for (final material in MockData.materials) {
      final haystack = '${material.subject} ${material.title}'.toLowerCase();
      if (query.isEmpty || haystack.contains(query.toLowerCase())) {
        grouped.putIfAbsent(material.subject, () => <MockMaterial>[]).add(material);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        const _Header(
          title: 'المواد الدراسية',
          subtitle: 'الفصل 8 • الهندسة • المواد المرتبطة بتخصصك',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Selector(
                label: 'الفصل $selectedSemester',
                icon: Icons.calendar_month_outlined,
                onTap: _pickSemester,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن مادة أو ملف',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (grouped.isEmpty)
          const _EmptyState()
        else
          for (final entry in grouped.entries)
            _Subject(
              subject: entry.key,
              code: entry.value.first.code,
              items: entry.value,
            ),
      ],
    );
  }

  Future<void> _pickSemester() async {
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('اختر الفصل الدراسي'),
        children: [
          for (var semester = 1; semester <= 10; semester++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, semester),
              child: Text('الفصل $semester'),
            ),
        ],
      ),
    );
    if (value != null && mounted) {
      setState(() => selectedSemester = value);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ],
    );
  }
}

class _Selector extends StatelessWidget {
  const _Selector({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.cyan, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Subject extends StatelessWidget {
  const _Subject({required this.subject, required this.code, required this.items});
  final String subject;
  final String code;
  final List<MockMaterial> items;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.menu_book_rounded, color: primary, size: 21),
        ),
        title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        subtitle: Text('$code • ${items.length} ملفات', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              leading: Icon(item.icon, color: AppColors.cyan, size: 21),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text('${item.pages} صفحات • Mock', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم فتح ${item.title}')),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 42, color: AppColors.muted),
          SizedBox(height: 10),
          Text('لا توجد نتائج', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

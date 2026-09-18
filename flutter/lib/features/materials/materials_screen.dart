import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';

class MaterialsScreen extends StatefulWidget { const MaterialsScreen({super.key}); @override State<MaterialsScreen> createState() => _MaterialsScreenState(); }
class _MaterialsScreenState extends State<MaterialsScreen> {
  String query = '';
  int selectedSemester = 8;
  @override Widget build(BuildContext context) {
    final grouped = <String, List<MockMaterial>>{};
    for (final m in MockData.materials) { if (query.isEmpty || '${m.subject} ${m.title}'.toLowerCase().contains(query.toLowerCase())) grouped.putIfAbsent(m.subject, () => []).add(m); }
    return ListView(padding: const EdgeInsets.fromLTRB(24, 22, 24, 100), children: [
      const _Header(title: 'المواد الدراسية', subtitle: 'الفصل 8 • الهندسة • المواد المرتبطة بتخصصك'),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: _Selector(label: 'الفصل $selectedSemester (الفصل الدراسي المعتمد)', icon: Icons.calendar_month_outlined, onTap: _pickSemester)), const SizedBox(width: 12), Expanded(child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'ابحث عن مادة أو ملف', prefixIcon: Icon(Icons.search_rounded))))]),
      const SizedBox(height: 24),
      for (final entry in grouped.entries) _Subject(subject: entry.key, code: entry.value.first.code, items: entry.value),
      const SizedBox(height: 20),
      const _Footer(),
    ]);
  }
  Future<void> _pickSemester() async {
    final value = await showDialog<int>(context: context, builder: (dialogContext) => SimpleDialog(title: const Text('اختر الفصل الدراسي'), children: [for (var i = 1; i <= 10; i++) SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, i), child: Text('الفصل $i'))]));
    if (value != null && mounted) setState(() => selectedSemester = value);
  }
}
class _Header extends StatelessWidget { const _Header({required this.title, required this.subtitle}); final String title, subtitle; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 7), Text(subtitle, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.muted, fontSize: 16))]); }
class _Selector extends StatelessWidget { const _Selector({required this.label, required this.icon, required this.onTap}); final String label; final IconData icon; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(icon, color: AppColors.cyan), const SizedBox(width: 12), Expanded(child: Text(label, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted)])); }
class _Subject extends StatelessWidget { const _Subject({required this.subject, required this.code, required this.items}); final String subject, code; final List<MockMaterial> items; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)), child: ExpansionTile(leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary)), title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), subtitle: Text('$code • ${items.length} ملفات', style: const TextStyle(color: AppColors.muted)), children: [for (final item in items) ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4), leading: Icon(item.icon, color: AppColors.cyan), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${item.pages} صفحات • بيانات تجريبية'), trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم فتح ${item.title} — Mock Data'))))])); }
class _Footer extends StatelessWidget { const _Footer(); @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.only(top: 18), child: Text('TRINEX • بيانات تجريبية محلية حتى اكتمال ربط Backend', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))); }

import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/models/material_item.dart';
import '../../data/repositories/materials_repository.dart';
import '../../shared/widgets/app_card.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  ApiClient? _client;
  MaterialsRepository? _repository;
  ProgressRepository? _progress;
  String? _semesterId;
  List<Map<String, dynamic>> _semesters = const [];
  List<Map<String, dynamic>> _subjects = const [];
  List<MaterialItem> _materials = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() { _client?.dispose(); super.dispose(); }

  Future<void> _init() async {
    try {
      _client = await AuthenticatedClient.create();
      _repository = MaterialsRepository(_client!);
      _progress = ProgressRepository(_client!);
      await _load();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _load({String? semesterId}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = _repository;
      if (repo == null) return;
      final semesters = await repo.semesters();
      final selected = semesterId ?? _semesterId ?? _currentSemester(semesters);
      final subjects = selected == null ? <Map<String, dynamic>>[] : await repo.subjects(semesterId: selected);
      final materials = selected == null ? <MaterialItem>[] : await repo.list(semesterId: selected);
      if (!mounted) return;
      setState(() { _semesters = semesters; _semesterId = selected; _subjects = subjects; _materials = materials; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String? _currentSemester(List<Map<String, dynamic>> items) {
    for (final item in items) { if (item['is_current'] == 1 || item['is_current'] == true) return item['id']?.toString(); }
    return items.isEmpty ? null : items.first['id']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading && _semesters.isEmpty) return Scaffold(appBar: AppBar(title: Text(l10n.t('materials'))), body: const Center(child: CircularProgressIndicator()));
    if (_error != null && _semesters.isEmpty) return Scaffold(appBar: AppBar(title: Text(l10n.t('materials'))), body: _Message(icon: Icons.cloud_off_outlined, text: 'تعذر تحميل المواد.\n$_error', retry: _load));

    final subjectGroups = <String, List<MaterialItem>>{};
    for (final material in _materials) { subjectGroups.putIfAbsent(material.subjectId ?? material.subject ?? 'other', () => []).add(material); }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('materials')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            DropdownButtonFormField<String>(
              value: _semesterId,
              decoration: const InputDecoration(labelText: 'الفصل الدراسي', prefixIcon: Icon(Icons.calendar_month_outlined)),
              items: _semesters.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text((s['name_ar'] ?? 'الفصل ${s['number'] ?? ''}').toString()))).toList(),
              onChanged: (value) { if (value != null) _load(semesterId: value); },
            ),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading && _subjects.isEmpty) const _EmptySubjects(),
            ..._subjects.map((subject) {
              final id = subject['id']?.toString() ?? '';
              final items = subjectGroups[id] ?? [];
              return _SubjectCard(subject: subject, materials: items, progress: _progress);
            }),
            if (!_loading && _subjects.isNotEmpty && _materials.isEmpty) const Padding(padding: EdgeInsets.all(24), child: _EmptyMaterials()),
          ],
        ),
      ),
    );
  }
}

Future<void> _openMaterial(BuildContext context, MaterialItem material, ProgressRepository? progress) async {
  if (progress != null) {
    try { await progress.record(materialId: material.id, eventType: 'open'); } catch (_) {}
  }
  if (!context.mounted) return;
  _showProgressSheet(context, material, progress);
}

void _showProgressSheet(BuildContext context, MaterialItem material, ProgressRepository? progress) {
  showModalBottomSheet(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.picture_as_pdf_rounded, size: 44), const SizedBox(height: 10),
    Text(material.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    if (material.url != null) SelectableText(material.url!, textAlign: TextAlign.center),
    const SizedBox(height: 14),
    const Text('حدّث تقدمك أثناء الدراسة. التقدم يحفظ على حسابك ولا يمنح XP لمجرد فتح الملف.', textAlign: TextAlign.center),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
      for (final value in [25, 50, 75, 100]) OutlinedButton(onPressed: progress == null ? null : () async { try { await progress.record(materialId: material.id, eventType: value == 100 ? 'complete' : 'progress', progressPercent: value); if (sheetContext.mounted) Navigator.pop(sheetContext); } catch (e) { if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر حفظ التقدم.'))); } }, child: Text('$value%'))
    ]),
  ]))));
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.materials, required this.progress});
  final Map<String, dynamic> subject;
  final List<MaterialItem> materials;
  final ProgressRepository? progress;
  @override Widget build(BuildContext context) {
    final name = (subject['name_ar'] ?? subject['name'] ?? 'مادة').toString();
    final code = (subject['code'] ?? '').toString();
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(code.isEmpty ? '${materials.length} ملف' : '$code • ${materials.length} ملف'),
        children: materials.isEmpty
            ? const [Padding(padding: EdgeInsets.all(20), child: Text('لا توجد ملفات لهذا المقرر حاليًا.'))]
            : materials.map((m) => ListTile(
                leading: Icon(m.pinned ? Icons.push_pin_rounded : Icons.picture_as_pdf_outlined),
                title: Text(m.name),
                subtitle: m.size == null || m.size == 0 ? null : Text(_formatSize(m.size!)),
                trailing: const Icon(Icons.chevron_left),
                onTap: m.url == null ? null : () => _openMaterial(context, m, progress),
              )).toList(),
      ),
    );
  }
  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _EmptySubjects extends StatelessWidget { const _EmptySubjects(); @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(30), child: Column(children: [Icon(Icons.school_outlined, size: 56), SizedBox(height: 12), Text('لا توجد مقررات متاحة لهذا الفصل والتخصص حاليًا.', textAlign: TextAlign.center)])); }
class _EmptyMaterials extends StatelessWidget { const _EmptyMaterials(); @override Widget build(BuildContext context) => const Column(children: [Icon(Icons.folder_open_outlined, size: 48), SizedBox(height: 10), Text('المقررات موجودة، لكن لا توجد ملفات منشورة بعد.', textAlign: TextAlign.center)]); }
class _Message extends StatelessWidget { const _Message({required this.icon, required this.text, this.retry}); final IconData icon; final String text; final VoidCallback? retry; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 60), const SizedBox(height: 14), Text(text, textAlign: TextAlign.center), if (retry != null) ...[const SizedBox(height: 14), OutlinedButton(onPressed: retry, child: const Text('إعادة المحاولة'))]]))); }

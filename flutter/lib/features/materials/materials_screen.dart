import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/models/material_item.dart';
import '../../data/repositories/materials_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/list_skeleton.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  ApiClient? _client;
  MaterialsRepository? _repository;
  ProgressRepository? _progress;
  String? _semesterId;
  Future<List<Map<String, dynamic>>>? _semestersFuture;
  List<Map<String, dynamic>> _semesters = const [];
  List<Map<String, dynamic>> _subjects = const [];
  List<MaterialItem> _materials = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

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
      final semesters = await (_semestersFuture ??= repo.semesters());
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
    if (_loading && _semesters.isEmpty) return Scaffold(appBar: AppBar(title: Text(l10n.t('materials'))), body: const ListSkeleton());
    if (_error != null && _semesters.isEmpty) return Scaffold(appBar: AppBar(title: Text(l10n.t('materials'))), body: _Message(icon: Icons.cloud_off_outlined, text: l10n.t('materialsLoadError', {'error': _error ?? ''}), retry: _load));

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
              initialValue: _semesterId,
              decoration: InputDecoration(labelText: l10n.t('semester'), prefixIcon: const Icon(Icons.calendar_month_outlined)),
              items: _semesters.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text(_localizedSemesterName(context, s, l10n)))).toList(),
              onChanged: (value) { if (value != null) _load(semesterId: value); },
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(hintText: l10n.t('materialSearch'), prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.close_rounded))),
            ),
            const SizedBox(height: 18),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (!_loading && _subjects.isEmpty) const _EmptySubjects(),
            ..._subjects.map((subject) {
              final id = subject['id']?.toString() ?? '';
              final allItems = subjectGroups[id] ?? [];
              final items = _query.isEmpty ? allItems : allItems.where((m) => m.name.toLowerCase().contains(_query)).toList();
              if (_query.isNotEmpty && items.isEmpty) return const SizedBox.shrink();
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
  final url = Uri.tryParse(material.url ?? '');
  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('cannotOpenMaterial'))));
    return;
  }
  final canOpen = await canLaunchUrl(url);
  if (!context.mounted) return;
  if (!canOpen) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('cannotOpenMaterial'))));
    return;
  }
  await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  _showProgressSheet(context, material, progress);
}

void _showProgressSheet(BuildContext context, MaterialItem material, ProgressRepository? progress) {
  showModalBottomSheet(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.picture_as_pdf_rounded, size: 44), const SizedBox(height: 10),
    Text(material.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    if (material.url != null) Text(AppLocalizations.of(context).t('materialOpenedExternally'), textAlign: TextAlign.center),
    const SizedBox(height: 14),
    Text(AppLocalizations.of(context).t('progressNote'), textAlign: TextAlign.center),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
      for (final value in [25, 50, 75, 100]) OutlinedButton(onPressed: progress == null ? null : () async { try { await progress.record(materialId: material.id, eventType: value == 100 ? 'complete' : 'progress', progressPercent: value); if (sheetContext.mounted) Navigator.pop(sheetContext); } catch (e) { if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(sheetContext).t('progressSaveError')))); } }, child: Text('$value%'))
    ]),
  ]))));
}

String _localizedSemesterName(BuildContext context, Map<String, dynamic> value, AppLocalizations l10n) {
  final code = Localizations.localeOf(context).languageCode;
  final candidates = code == 'fr'
      ? [value['name_fr'], value['name_en'], value['name_ar']]
      : code == 'en'
          ? [value['name_en'], value['name_ar']]
          : [value['name_ar'], value['name_en']];
  for (final candidate in candidates) {
    if (candidate != null && candidate.toString().trim().isNotEmpty) return candidate.toString();
  }
  return l10n.t('semesterFallback', {'number': '${value['number'] ?? ''}'});
}

String _localizedSubjectName(BuildContext context, Map<String, dynamic> value, AppLocalizations l10n) {
  final code = Localizations.localeOf(context).languageCode;
  final candidates = code == 'fr'
      ? [value['name_fr'], value['name_en'], value['name_ar'], value['name']]
      : code == 'en'
          ? [value['name_en'], value['name_ar'], value['name']]
          : [value['name_ar'], value['name_en'], value['name']];
  for (final candidate in candidates) {
    if (candidate != null && candidate.toString().trim().isNotEmpty) return candidate.toString();
  }
  return l10n.t('subjectFallback');
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.materials, required this.progress});
  final Map<String, dynamic> subject;
  final List<MaterialItem> materials;
  final ProgressRepository? progress;
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _localizedSubjectName(context, subject, l10n);
    final code = (subject['code'] ?? '').toString();
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(code.isEmpty ? l10n.t('fileCount', {'count': '${materials.length}'}) : '$code • ${l10n.t('fileCount', {'count': '${materials.length}'})}'),
        children: materials.isEmpty
            ? [Padding(padding: const EdgeInsets.all(20), child: Text(l10n.t('noMaterialFiles')))]
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

class _EmptySubjects extends StatelessWidget { const _EmptySubjects(); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(30), child: Column(children: [const Icon(Icons.school_outlined, size: 56), const SizedBox(height: 12), Text(AppLocalizations.of(context).t('noSubjects'), textAlign: TextAlign.center)])); }
class _EmptyMaterials extends StatelessWidget { const _EmptyMaterials(); @override Widget build(BuildContext context) => Column(children: [const Icon(Icons.folder_open_outlined, size: 48), const SizedBox(height: 10), Text(AppLocalizations.of(context).t('noPublishedFiles'), textAlign: TextAlign.center)]); }
class _Message extends StatelessWidget { const _Message({required this.icon, required this.text, this.retry}); final IconData icon; final String text; final VoidCallback? retry; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 60), const SizedBox(height: 14), Text(text, textAlign: TextAlign.center), if (retry != null) ...[const SizedBox(height: 14), OutlinedButton(onPressed: retry, child: Text(AppLocalizations.of(context).t('retry')))]]))); }

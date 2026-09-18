import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/material_item.dart';
import '../../data/repositories/materials_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../shared/widgets/app_card.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  ApiClient? _client;
  late Future<List<MaterialItem>> _future;
  List<Map<String, dynamic>> _semesters = [];
  String? _semesterId;
  String _query = '';

  @override void initState() { super.initState(); _future = _load(); }

  Future<List<MaterialItem>> _load() async {
    _client ??= await AuthenticatedClient.create();
    final repo = MaterialsRepository(_client!);
    final semesters = await repo.semesters();
    if (mounted && _semesters.isEmpty) {
      setState(() {
        _semesters = semesters;
        _semesterId ??= semesters.isEmpty ? null : semesters.first['id']?.toString();
      });
    }
    return repo.list(semesterId: _semesterId);
  }

  Future<void> _reload() async { final future = _load(); setState(() => _future = future); await future; }

  @override void dispose() { _client?.dispose(); super.dispose(); }

  Future<void> _openMaterial(MaterialItem material) async {
    final url = material.url?.trim();
    if (url == null || url.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رابط الملف غير متاح حاليًا')));
      return;
    }
    try {
      _client ??= await AuthenticatedClient.create();
      await ProgressRepository(_client!).record(materialId: material.id, eventType: 'open', progressPercent: 0);
    } catch (_) {}
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الملف')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<MaterialItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _State(message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : l10n.t('connectionFailed'), retry: _reload);
          final all = snapshot.data ?? const <MaterialItem>[];
          final filtered = all.where((m) => _query.isEmpty || '${m.name} ${m.subject ?? ''} ${m.subjectCode ?? ''}'.toLowerCase().contains(_query.toLowerCase())).toList();
          final groups = <String, List<MaterialItem>>{};
          for (final material in filtered) groups.putIfAbsent(material.subject ?? 'مواد', () => <MaterialItem>[]).add(material);
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(14.72, 12, 14.72, 92),
            children: [
              const Text('المواد الدراسية', textAlign: TextAlign.end, style: TextStyle(fontSize: 20.2, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('المواد المتاحة حسب تخصصك وفصلك الدراسي', textAlign: TextAlign.end, style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 11.5)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(onChanged: (value) => setState(() => _query = value), decoration: const InputDecoration(hintText: 'بحث', prefixIcon: Icon(Icons.search_rounded)))),
                if (_semesters.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  SizedBox(width: 118, child: DropdownButtonFormField<String>(
                    value: _semesterId,
                    items: [for (final semester in _semesters) DropdownMenuItem(value: semester['id']?.toString(), child: Text(semester['name_ar']?.toString() ?? 'فصل', overflow: TextOverflow.ellipsis)),],
                    onChanged: (value) { if (value == null) return; setState(() => _semesterId = value); _reload(); },
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_month_rounded)),
                  )),
                ],
              ]),
              const SizedBox(height: 12),
              if (groups.isEmpty) AppCard(child: Text(l10n.t('noData'), textAlign: TextAlign.center))
              else for (final entry in groups.entries) Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    subtitle: Text('${entry.value.length} ملفات', style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 10)),
                    children: [for (final material in entry.value) ListTile(
                      dense: true,
                      title: Text(material.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(material.size == null ? '' : '${material.size} bytes', style: TextStyle(fontSize: 9, color: context.colors.onSurfaceVariant)),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 15),
                      onTap: () => _openMaterial(material),
                    )],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _State extends StatelessWidget {
  const _State({required this.message, required this.retry});
  final String message; final VoidCallback retry;
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 10), FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(AppLocalizations.of(context).t('retry')))]));
}

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/errors/error_message.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/material_progress.dart';
import '../../data/repositories/progress_repository.dart';
import '../materials/materials_screen.dart';

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  late Future<ProgressSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProgressSnapshot> _load() =>
      AppDependencies.instance.progress.getProgress(forceRefresh: true);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder displays the failure state.
    }
  }

  Future<void> _open(MaterialProgress progress) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Fetch this exact material by ID so old items remain openable even
      // when they are outside the current semester or the first page of results.
      final material = await AppDependencies.instance.materials.getById(progress.materialId);
      if (!mounted) return;
      final selectedMaterial = material;
      if (selectedMaterial.url?.trim().isEmpty ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('openMaterialUnavailable'))),
        );
        return;
      }

      final token = await AppDependencies.instance.authStorage.accessToken;
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.t('loginToOpenMaterial'))),
        );
        return;
      }
      if ((selectedMaterial.mimeType ?? '').toLowerCase() != 'application/pdf') {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.t('notPdf'))),
        );
        return;
      }

      // Record the new opening before displaying the PDF so the list updates
      // its ordering the next time it is refreshed.
      await AppDependencies.instance.progress.record(
        materialId: selectedMaterial.id,
        eventType: 'open',
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PdfMaterialViewerScreen(
          title: selectedMaterial.name,
          materialId: selectedMaterial.id,
          url: Uri.parse(
            '${AppConstants.apiBaseUrl}/api/v1/materials/${Uri.encodeComponent(selectedMaterial.id)}/file',
          ),
          accessToken: token,
        ),
      ));
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessage.from(
          context,
          error,
          fallbackKey: 'openMaterialFailed',
        ))),
      );
    }
  }

  DateTime? _date(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _dateLabel(BuildContext context, String? raw) {
    final date = _date(raw);
    if (date == null) return '';
    final now = DateTime.now();
    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    final time = TimeOfDay.fromDateTime(date).format(context);
    if (sameDay) return '${AppLocalizations.of(context).t('today')} · $time';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('recent')),
        actions: [IconButton(
          tooltip: l10n.t('retry'),
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        )],
      ),
      body: FutureBuilder<ProgressSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_rounded,
              message: l10n.t('progressLoadError'),
              actionLabel: l10n.t('retry'),
              onAction: _refresh,
            );
          }
          final items = [...?snapshot.data?.items]
            ..removeWhere((item) => item.materialId.isEmpty || item.lastOpenedAt == null);
          items.sort((a, b) {
            final ad = _date(a.lastOpenedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = _date(b.lastOpenedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          });
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [SizedBox(
                  height: MediaQuery.sizeOf(context).height * .62,
                  child: _MessageState(
                    icon: Icons.history_rounded,
                    message: l10n.t('recentEmpty'),
                  ),
                )],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final percent = item.percent.clamp(0, 100);
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(item),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 54,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.picture_as_pdf_rounded,
                              color: theme.colorScheme.onPrimaryContainer, size: 27),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (item.materialTitle?.trim().isNotEmpty == true)
                                    ? item.materialTitle!.trim()
                                    : l10n.t('materials'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (item.subjectName?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 3),
                                Text(item.subjectName!, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                              ],
                              const SizedBox(height: 5),
                              Text(_dateLabel(context, item.lastOpenedAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(value: percent / 100, minHeight: 5),
                                )),
                                const SizedBox(width: 8),
                                Text('$percent%', style: theme.textTheme.labelSmall),
                              ]),
                            ],
                          )),
                          const SizedBox(width: 6),
                          Icon(Icons.open_in_new_rounded, size: 19,
                            color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 54, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh_rounded), label: Text(actionLabel!)),
        ],
      ]),
    ),
  );
}

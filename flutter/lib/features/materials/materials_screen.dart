import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/constants/app_constants.dart';
import '../../core/storage/auth_storage.dart';
import '../../data/models/material_item.dart';
import '../../data/models/material_progress.dart';
import '../../data/models/student_profile.dart';
import '../../data/repositories/materials_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/login_required_card.dart';
import '../../shared/widgets/trinex_shell.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  ApiClient? _client;
  late Future<List<MaterialItem>> _future;
  List<Map<String, dynamic>> _semesters = [];
  String? _semesterId;
  String _query = '';
  Future<ProgressSnapshot>? _progressFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MaterialItem>> _load() async {
    _client ??= await AuthenticatedClient.create();

    _progressFuture ??= ProgressRepository(_client!).getProgress();

    final repo = MaterialsRepository(_client!);
    final studentRepo = StudentRepository(_client!);
    final results = await Future.wait([
      repo.semesters(),
      studentRepo.profile(),
    ]);
    final semesters = results[0] as List<Map<String, dynamic>>;
    final profile = results[1] as StudentProfile;
    final registeredSemesterId = profile.semesterId?.trim();
    final registeredExists = registeredSemesterId != null &&
        semesters.any((semester) => semester['id']?.toString() == registeredSemesterId);

    if (mounted) {
      setState(() {
        _semesters = semesters;
        if (_semesterId == null ||
            !semesters.any((semester) => semester['id']?.toString() == _semesterId)) {
          _semesterId = registeredExists
              ? registeredSemesterId
              : (semesters.isEmpty ? null : semesters.first['id']?.toString());
        }
      });
    }

    return repo.list(semesterId: _semesterId);
  }

  Future<void> _reload() async {
    _progressFuture = null;
    final future = _load();

    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder owns the visible error state.
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  Future<void> _openMaterial(MaterialItem material) async {
    final l10n = AppLocalizations.of(context);
    final url = material.url?.trim();

    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('openMaterialUnavailable'))),
        );
      }
      return;
    }

    try {
      _client ??= await AuthenticatedClient.create();

      // Progress is recorded against the material ID, never against a
      // provider/Drive URL.
      await ProgressRepository(_client!).record(
        materialId: material.id,
        eventType: 'open',
        progressPercent: 0,
      );

      final storage = await AuthStorage.create();
      final token = await storage.accessToken;
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('loginToOpenMaterial'))),
          );
        }
        return;
      }

      if ((material.mimeType ?? '').toLowerCase() != 'application/pdf') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('notPdf'))),
          );
        }
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfMaterialViewerScreen(
            title: material.name,
            materialId: material.id,
            url: Uri.parse('${AppConstants.apiBaseUrl}/api/v1/materials/${Uri.encodeComponent(material.id)}/file'),
            accessToken: token,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : l10n.t('openMaterialFailed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<MaterialItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            final e = snapshot.error;
            if (e is ApiException && (e.kind == ApiErrorKind.auth || e.code == 'AUTH_REQUIRED')) return const LoginRequiredCard();
            return _State(
              message: e is ApiException
                  ? (snapshot.error as ApiException).message
                  : l10n.t('connectionFailed'),
              retry: _reload,
            );
          }

          final all = snapshot.data ?? const <MaterialItem>[];

          final filtered = all
              .where(
                (material) =>
                    _query.isEmpty ||
                    '${material.name} '
                            '${material.subject ?? ''} '
                            '${material.subjectCode ?? ''}'
                        .toLowerCase()
                        .contains(_query.toLowerCase()),
              )
              .toList();

          final groups = <String, List<MaterialItem>>{};

          for (final material in filtered) {
            groups
                .putIfAbsent(
                  material.subject ?? l10n.t('materials'),
                  () => <MaterialItem>[],
                )
                .add(material);
          }

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              14.72,
              12,
              14.72,
              92,
            ),
            children: [
              Text(
                l10n.t('materialsTitle'),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 20.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.t('materialsSubtitle'),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        setState(() => _query = value);
                      },
                      decoration: InputDecoration(
                        hintText: l10n.t('search'),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                        ),
                      ),
                    ),
                  ),
                  if (_semesters.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 142,
                      child: DropdownButtonFormField<String>(
                        initialValue: _semesterId,
                        isExpanded: true,
                        alignment: Alignment.centerRight,
                        items: [
                          for (final semester in _semesters)
                            DropdownMenuItem(
                              value: semester['id']?.toString(),
                              child: Text(
                                semester['name_ar']?.toString() ?? 'فصل',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            _semesterId = value;
                          });

                          _reload();
                        },
                        decoration: const InputDecoration(),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (groups.isEmpty)
                AppCard(
                  child: Text(
                    l10n.t('noData'),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final entry in groups.entries)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 9),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        title: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          l10n.t('filesCount', {'count': '${entry.value.length}'}),
                          style: TextStyle(
                            color:
                                context.colors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        children: [
                          for (final material in entry.value)
                            _MaterialRow(
                              material: material,
                              progressFuture: _progressFuture,
                              onTap: () => _openMaterial(material),
                            ),
                        ],
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


class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.progressFuture,
    required this.onTap,
  });

  final MaterialItem material;
  final Future<ProgressSnapshot>? progressFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<ProgressSnapshot>(
      future: progressFuture,
      builder: (context, snapshot) {
        MaterialProgress? progress;
        for (final item in snapshot.data?.items ?? const <MaterialProgress>[]) {
          if (item.materialId == material.id) {
            progress = item;
            break;
          }
        }
        final percent = ((progress?.percent ?? 0).clamp(0, 100)).toDouble();
        final completed = progress?.completed == true || percent >= 100;

        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            material.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w700),
                          ),
                          if (material.size != null && material.size! > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatFileSize(material.size!),
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 5,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      completed ? l10n.t('completed') : '${l10n.t('progress')}: $percent%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: completed ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) return '';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final decimals = index == 0 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(decimals)} ${units[index]}';
}

class PdfMaterialViewerScreen extends StatefulWidget {
  const PdfMaterialViewerScreen({
    required this.title,
    required this.materialId,
    required this.url,
    required this.accessToken,
    super.key,
  });

  final String title;
  final String materialId;
  final Uri url;
  final String accessToken;

  @override
  State<PdfMaterialViewerScreen> createState() => _PdfMaterialViewerScreenState();
}

class _PdfMaterialViewerScreenState extends State<PdfMaterialViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  Timer? _progressTimer;
  ApiClient? _progressClient;
  File? _localPdf;
  int _lastReportedProgress = 0;
  bool _loadingFile = true;
  Object? _loadError;
  final PdfViewerController _pdfController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _loadPdfToDisk();
  }

  Future<void> _loadPdfToDisk() async {
    try {
      final directory = await getTemporaryDirectory();
      final safeId = widget.materialId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${directory.path}/trinex_material_$safeId.pdf');

      // Reuse a previously downloaded copy when it exists. The server remains
      // authoritative; the cache only avoids repeating a large download.
      if (!await file.exists() || await file.length() == 0) {
        final request = http.Request('GET', widget.url)
          ..headers['Authorization'] = 'Bearer ${widget.accessToken}'
          ..headers['Accept'] = 'application/pdf';
        final response = await request.send().timeout(const Duration(minutes: 3));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('PDF download failed (${response.statusCode}).');
        }

        final sink = file.openWrite();
        try {
          await response.stream.pipe(sink);
        } catch (_) {
          await sink.close();
          if (await file.exists()) await file.delete();
          rethrow;
        }
      }

      if (!mounted) return;
      setState(() {
        _localPdf = file;
        _loadingFile = false;
      });
      _startProgressTracking();
      await _sendProgress(10);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadingFile = false;
      });
    }
  }

  void _startProgressTracking() {
    // Time is only a conservative reading signal. We deliberately stop at
    // 75%; 100% is reserved for an actual end-of-document page event.
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted) return;
      final next = (_lastReportedProgress + 25).clamp(25, 75);
      if (next > _lastReportedProgress) _sendProgress(next);
    });
  }

  Future<void> _sendProgress(int percent) async {
    if (percent <= _lastReportedProgress) return;
    try {
      _progressClient ??= await AuthenticatedClient.create();
      await ProgressRepository(_progressClient!).record(
        materialId: widget.materialId,
        eventType: percent >= 100 ? 'complete' : 'progress',
        progressPercent: percent,
      );
      _lastReportedProgress = percent;
    } catch (_) {
      // Progress is auxiliary; a temporary network failure must not close the PDF.
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _progressClient?.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loadingFile
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null || _localPdf == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).t('openMaterialFailed'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _loadingFile = true;
                              _loadError = null;
                            });
                            _loadPdfToDisk();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(AppLocalizations.of(context).t('retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    PdfViewer.file(
                      _localPdf!.path,
                      controller: _pdfController,
                      useProgressiveLoading: true,
                      params: PdfViewerParams(
                        backgroundColor: cs.surfaceContainerHighest,
                        maxImageBytesCachedOnMemory: 32 * 1024 * 1024,
                        verticalCacheExtent: 1.0,
                        onePassRenderingSizeThreshold: 1600,
                        onPageChanged: (pageNumber) {
                          if (pageNumber != null &&
                              _pdfController.isReady &&
                              _pdfController.pageCount > 0 &&
                              pageNumber >= _pdfController.pageCount) {
                            _sendProgress(100);
                          }
                        },
                        linkHandlerParams: PdfLinkHandlerParams(
                          onLinkTap: (_) {},
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

}

class _State extends StatelessWidget {
  const _State({
    required this.message,
    required this.retry,
  });

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              AppLocalizations.of(context).t('retry'),
            ),
          ),
        ],
      ),
    );
  }
}
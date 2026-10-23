import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/material_item.dart';
import '../../data/models/material_progress.dart';
import '../../data/models/student_profile.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/downloaded_materials_store.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/login_required_card.dart';
import '../../shared/widgets/animated_download_button.dart';

part 'material_row.dart';
part 'pdf_material_viewer.dart';
part 'materials_state_widget.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  late Future<List<MaterialItem>> _future;
  List<Map<String, dynamic>> _semesters = [];
  String? _semesterId;
  String _query = '';
  bool _searchExpanded = false;
  bool _examMode = false;
  Future<List<MaterialItem>>? _examFuture;
  Future<ProgressSnapshot>? _progressFuture;
  final Set<String> _downloadingIds = <String>{};
  final DownloadedMaterialsStore _downloadStore = DownloadedMaterialsStore();
  final Map<String, DownloadedMaterial> _downloadedMaterials = <String, DownloadedMaterial>{};
  final Map<String, DownloadActionPhase> _downloadPhases = <String, DownloadActionPhase>{};
  final Map<String, double?> _downloadProgress = <String, double?>{};
  Future<void>? _downloadsLoadFuture;
  String? _downloadOwnerKey;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _downloadsLoadFuture = _loadDownloadedMaterials();
  }

  Future<String> _currentOwnerKey() async {
    final profile = await AppDependencies.instance.authStorage.profile;
    return (profile?['studentId'] ?? profile?['studentNumber'] ?? 'guest').toString();
  }

  Future<void> _loadDownloadedMaterials() async {
    try {
      final ownerKey = await _currentOwnerKey();
      final items = await _downloadStore.list(ownerKey: ownerKey);
      if (!mounted) return;
      setState(() {
        final ownerChanged = _downloadOwnerKey != ownerKey;
        _downloadOwnerKey = ownerKey;
        if (ownerChanged) {
          _downloadedMaterials.clear();
          _downloadPhases.clear();
          _downloadProgress.clear();
          for (final id in _downloadingIds) {
            _downloadPhases[id] = DownloadActionPhase.downloading;
          }
        }
        _downloadedMaterials.addEntries(
          items.map((item) => MapEntry(item.materialId, item)),
        );
        for (final item in items) {
          if (!_downloadingIds.contains(item.materialId)) {
            _downloadPhases[item.materialId] = DownloadActionPhase.view;
          }
        }
      });
    } catch (_) {
      // A storage read failure should not block opening online material.
    }
  }

  Future<void> _ensureDownloadsLoaded() async {
    await (_downloadsLoadFuture ??= _loadDownloadedMaterials());
    final ownerKey = await _currentOwnerKey();
    if (_downloadOwnerKey != ownerKey) {
      _downloadsLoadFuture = _loadDownloadedMaterials();
      await _downloadsLoadFuture;
    }
  }

  Future<DownloadedMaterial?> _findDownloadedMaterial(String materialId) async {
    await _ensureDownloadsLoaded();
    var item = _downloadedMaterials[materialId];
    try {
      if (item != null && await _downloadStore.isValidPdfFile(item.file)) {
        return item;
      }
      final ownerKey = await _currentOwnerKey();
      item = await _downloadStore.findByMaterialId(
        ownerKey: ownerKey,
        materialId: materialId,
      );
      if (item != null && mounted) {
        setState(() {
          _downloadedMaterials[materialId] = item!;
          _downloadPhases[materialId] = DownloadActionPhase.view;
        });
      } else if (mounted) {
        setState(() {
          _downloadedMaterials.remove(materialId);
          if (!_downloadingIds.contains(materialId)) {
            _downloadPhases[materialId] = DownloadActionPhase.idle;
          }
        });
      }
      return item;
    } on FileSystemException {
      if (mounted) {
        setState(() {
          _downloadedMaterials.remove(materialId);
          _downloadPhases[materialId] = DownloadActionPhase.idle;
        });
      }
      return null;
    }
  }

  Future<List<MaterialItem>> _load() async {

    _progressFuture ??= AppDependencies.instance.progress.getProgress();

    final repo = AppDependencies.instance.materials;
    final studentRepo = AppDependencies.instance.student;
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
      if (_examMode) {
        _examFuture = AppDependencies.instance.materials.exams(semesterId: _semesterId);
      }
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder owns the visible error state.
    }
  }



  Future<void> _openMaterial(MaterialItem material) async {
    final l10n = AppLocalizations.of(context);

    if ((material.mimeType ?? '').toLowerCase() != 'application/pdf') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('notPdf'))),
        );
      }
      return;
    }

    try {
      final downloaded = await _findDownloadedMaterial(material.id);
      final localFile = downloaded?.file;
      final hasLocalFile = localFile != null &&
          await _downloadStore.isValidPdfFile(localFile);
      final url = material.url?.trim();
      if (!hasLocalFile && (url == null || url.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('openMaterialUnavailable'))),
          );
        }
        return;
      }

      final token = await AppDependencies.instance.authStorage.accessToken;
      if (!hasLocalFile && (token == null || token.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('loginToOpenMaterial'))),
          );
        }
        return;
      }

      // Opening a saved copy must still work in airplane mode. Progress sync is
      // best-effort and must never block access to the local PDF.
      if (!hasLocalFile && token != null && token.isNotEmpty) {
        try {
          await AppDependencies.instance.progress.record(
            materialId: material.id,
            eventType: 'open',
            progressPercent: 0,
          ).timeout(const Duration(seconds: 3));
        } catch (_) {
          // Offline progress can be reconciled on a later visit.
        }
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfMaterialViewerScreen(
            title: material.name,
            materialId: material.id,
            url: token == null || token.isEmpty
                ? null
                : Uri.parse('${AppConstants.apiBaseUrl}/api/v1/materials/${Uri.encodeComponent(material.id)}/file'),
            accessToken: token ?? '',
            localFile: hasLocalFile ? localFile : null,
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _progressFuture = AppDependencies.instance.progress.getProgress();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'openMaterialFailed'))),
        );
      }
    }
  }

  Future<void> _openExam(MaterialItem exam) async {
    final l10n = AppLocalizations.of(context);
    if ((exam.mimeType ?? '').toLowerCase() != 'application/pdf') {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('notPdf'))));
      return;
    }

    final downloaded = await _findDownloadedMaterial(exam.id);
    final localFile = downloaded?.file;
    final hasLocalFile = localFile != null &&
        await _downloadStore.isValidPdfFile(localFile);
    final token = await AppDependencies.instance.authStorage.accessToken;
    if (!hasLocalFile && (token == null || token.isEmpty)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('loginToOpenMaterial'))));
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PdfMaterialViewerScreen(
      title: exam.name,
      materialId: exam.id,
      url: token == null || token.isEmpty
          ? null
          : Uri.parse('${AppConstants.apiBaseUrl}/api/v1/materials/${Uri.encodeComponent(exam.id)}/file'),
      accessToken: token ?? '',
      localFile: hasLocalFile ? localFile : null,
      trackProgress: false,
    )));
  }

  Future<void> _downloadMaterial(MaterialItem material) async {
    if (_downloadingIds.contains(material.id)) return;
    final l10n = AppLocalizations.of(context);
    await _ensureDownloadsLoaded();
    if (!mounted || _downloadingIds.contains(material.id)) return;
    if (_downloadedMaterials.containsKey(material.id)) {
      if (_examMode) {
        await _openExam(material);
      } else {
        await _openMaterial(material);
      }
      return;
    }
    setState(() {
      _downloadingIds.add(material.id);
      _downloadPhases[material.id] = DownloadActionPhase.downloading;
      _downloadProgress[material.id] = 0.0;
    });

    final client = http.Client();
    String? startedOwnerKey;
    try {
      final ownerKey = await _currentOwnerKey();
      startedOwnerKey = ownerKey;
      final token = await AppDependencies.instance.authStorage.accessToken;
      if (token == null || token.isEmpty) throw Exception(l10n.t('loginToOpenMaterial'));
      if ((material.mimeType ?? '').toLowerCase() != 'application/pdf') {
        throw Exception(l10n.t('notPdf'));
      }

      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/v1/materials/${Uri.encodeComponent(material.id)}/file');
      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/pdf';
      final response = await client.send(request).timeout(const Duration(minutes: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('تعذر تنزيل الملف (HTTP ${response.statusCode}).');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      var lastShownPercent = -1;
      var unknownProgressShown = false;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(const Duration(minutes: 3))) {
        builder.add(chunk);
        receivedBytes += chunk.length;
        if (!mounted) continue;
        if (totalBytes != null && totalBytes > 0) {
          final ratio = (receivedBytes / totalBytes).clamp(0.0, 1.0).toDouble();
          final shownPercent = (ratio * 100).round();
          if (shownPercent != lastShownPercent) {
            lastShownPercent = shownPercent;
            setState(() => _downloadProgress[material.id] = ratio);
          }
        } else if (!unknownProgressShown) {
          unknownProgressShown = true;
          setState(() => _downloadProgress[material.id] = null);
        }
      }

      if (totalBytes != null &&
          totalBytes > 0 &&
          (response.headers['content-encoding'] == null ||
              response.headers['content-encoding'] == 'identity') &&
          receivedBytes != totalBytes) {
        throw Exception('اكتمل الاتصال قبل استلام الملف كاملًا.');
      }

      final bytes = builder.takeBytes();
      final saved = await _downloadStore.save(
        ownerKey: ownerKey,
        materialId: material.id,
        title: material.name,
        bytes: bytes,
      );
      if (!mounted) return;
      final activeOwnerKey = await _currentOwnerKey();
      if (activeOwnerKey != ownerKey) {
        _downloadsLoadFuture = _loadDownloadedMaterials();
        return;
      }

      setState(() {
        _downloadedMaterials[material.id] = saved.item;
        _downloadPhases[material.id] = DownloadActionPhase.success;
        _downloadProgress.remove(material.id);
      });
      final message = l10n.t(
        saved.savedToPublicDownloads ? 'downloadSavedPublic' : 'downloadSavedOffline',
        {'name': material.name},
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      var ownerStillActive = true;
      try {
        final activeOwnerKey = await _currentOwnerKey();
        ownerStillActive = startedOwnerKey == null || activeOwnerKey == startedOwnerKey;
      } catch (_) {
        // Preserve the visible failure if the account identity itself cannot be read.
      }
      if (!ownerStillActive) {
        _downloadsLoadFuture = _loadDownloadedMaterials();
        return;
      }
      setState(() {
        _downloadPhases[material.id] = DownloadActionPhase.failed;
        _downloadProgress.remove(material.id);
      });
      final message = e is Exception && e.toString().contains('HTTP')
          ? e.toString().replaceFirst('Exception: ', '')
          : l10n.t('downloadFailed');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _downloadingIds.remove(material.id);
          if (_downloadPhases[material.id] == DownloadActionPhase.downloading) {
            _downloadPhases[material.id] = _downloadedMaterials.containsKey(material.id)
                ? DownloadActionPhase.view
                : DownloadActionPhase.idle;
          }
        });
      }
    }
  }

  void _finishSuccessAnimation(String materialId) {
    if (!mounted || _downloadPhases[materialId] != DownloadActionPhase.success) return;
    setState(() => _downloadPhases[materialId] = DownloadActionPhase.view);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<MaterialItem>>(
        future: _examMode ? (_examFuture ??= AppDependencies.instance.materials.exams(semesterId: _semesterId)) : _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            final Object e = snapshot.error ?? Exception('Unknown error');
            if (e is ApiException && (e.kind == ApiErrorKind.auth || e.code == 'AUTH_REQUIRED')) return const LoginRequiredCard();
            return _State(
              message: e is ApiException
                  ? e.message
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
                l10n.t(_examMode ? 'previousExamsTitle' : 'materialsTitle'),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 20.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.t(_examMode ? 'previousExamsSubtitle' : 'materialsSubtitle'),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 14),
              // Search sits on its own row above the semester/mode controls.
              // The compact state is a circular icon; tapping it expands into
              // a real search field without stealing space from the controls.
              LayoutBuilder(
                builder: (context, constraints) {
                  final expandedWidth = constraints.maxWidth;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ClipRect(
                        child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        width: _searchExpanded ? expandedWidth : 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(_searchExpanded ? 16 : 24),
                          border: Border.all(color: context.colors.outlineVariant),
                        ),
                        child: _searchExpanded
                            ? Row(
                                children: [
                                  const SizedBox(width: 14),
                                  Icon(Icons.search_rounded, color: context.colors.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      autofocus: true,
                                      onChanged: (value) => setState(() => _query = value),
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                        hintText: l10n.t('search'),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.t('cancel'),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() {
                                      _searchExpanded = false;
                                      _query = '';
                                    }),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              )
                            : IconButton(
                                tooltip: l10n.t('search'),
                                onPressed: () => setState(() => _searchExpanded = true),
                                icon: const Icon(Icons.search_rounded),
                              ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_semesters.isNotEmpty)
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 54,
                        child: DropdownButtonFormField<String>(
                          initialValue: _semesterId,
                          isExpanded: true,
                          alignment: Alignment.centerRight,
                          icon: const Icon(Icons.expand_more_rounded, size: 24),
                          items: [
                            for (final semester in _semesters)
                              DropdownMenuItem(
                                value: semester['id']?.toString(),
                                child: Text(
                                  semester['name_ar']?.toString() ?? l10n.t('semester'),
                                  textAlign: TextAlign.start,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _semesterId = value);
                            _reload();
                          },
                          decoration: InputDecoration(
                            labelText: l10n.t('semester'),
                            contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  if (_semesters.isNotEmpty) const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(color: context.colors.outlineVariant),
                        ),
                        onPressed: () {
                          setState(() {
                            _examMode = !_examMode;
                            _query = '';
                            if (_examMode) _examFuture = AppDependencies.instance.materials.exams(semesterId: _semesterId);
                          });
                        },
                        icon: Icon(_examMode ? Icons.menu_book_rounded : Icons.assignment_rounded, size: 19),
                        label: Text(
                          l10n.t(_examMode ? 'studyMaterialsButton' : 'previousExamsButton'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
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
                              progressFuture: _examMode ? null : _progressFuture,
                              showProgress: !_examMode,
                              downloadTooltip: l10n.t(_examMode ? 'downloadExam' : 'downloadSheet'),
                              onTap: () => _examMode ? _openExam(material) : _openMaterial(material),
                              onDownload: () => _downloadMaterial(material),
                              onView: () => _examMode ? _openExam(material) : _openMaterial(material),
                              downloadPhase: _downloadPhases[material.id] ?? DownloadActionPhase.idle,
                              downloadProgress: _downloadProgress[material.id],
                              onSuccessAnimationComplete: () => _finishSuccessAnimation(material.id),
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



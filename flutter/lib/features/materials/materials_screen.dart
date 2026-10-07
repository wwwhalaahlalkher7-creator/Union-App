import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/constants/app_constants.dart';
import '../../core/storage/auth_storage.dart';
import '../../data/models/material_item.dart';
import '../../data/models/material_progress.dart';
import '../../data/models/student_profile.dart';
import '../../data/repositories/materials_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/login_required_card.dart';

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
  Future<ProgressSnapshot>? _progressFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
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
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder owns the visible error state.
    }
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
  
      // Progress is recorded against the material ID, never against a
      // provider/Drive URL.
      await AppDependencies.instance.progress.record(
        materialId: material.id,
        eventType: 'open',
        progressPercent: 0,
      );

      final storage = AppDependencies.instance.authStorage;
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
            final Object e = snapshot.error ?? Exception('Unknown error');
            if (e is ApiException && (e.kind == ApiErrorKind.auth || e.code == 'AUTH_REQUIRED')) return const LoginRequiredCard();
            return _State(
              message: e is ApiException
                  ? (e as ApiException).message
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
                                semester['name_ar']?.toString() ?? l10n.t('semester'),
                                textAlign: TextAlign.start,
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



import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/student_profile.dart';
import '../../data/repositories/student_repository.dart';
import '../../shared/widgets/app_card.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  ApiClient? _client;
  late Future<_StudentData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StudentData> _load() async {
    _client ??= await AuthenticatedClient.create();

    final repository = StudentRepository(_client!);
    final profile = await repository.profile();
    final stats = await repository.stats();

    return _StudentData(profile, stats);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });

    await _future;
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<_StudentData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            final e = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e is ApiException ? e.message : AppLocalizations.of(context).t('connectionFailed'), textAlign: TextAlign.center),
                    if (e is! ApiException || e.retryable) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh_rounded), label: Text(AppLocalizations.of(context).t('retry'))),
                    ],
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final profile = data.profile;
          final stats = data.stats;

          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              14.72,
              12,
              14.72,
              92,
            ),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            context.colors.secondary,
                            context.colors.primary,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.departmentName ?? '',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _Pill(profile.number),
                    const SizedBox(height: 12),
                    Text(
                      profile.semesterName ?? 'الفصل غير محدد',
                      style: TextStyle(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        'المستوى',
                        '${stats['level'] ?? 1}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Stat(
                        'XP',
                        '${stats['xp_total'] ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Stat(
                        'الفصل',
                        profile.semesterName ?? '—',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Action(
                      'المواد',
                      Icons.menu_book_rounded,
                      () => context.go('/materials'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Action(
                      'الجدول',
                      Icons.calendar_month_rounded,
                      () => context.go('/schedule'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Action(
                      'الشارات',
                      Icons.workspace_premium_rounded,
                      () => context.go('/badges'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentData {
  const _StudentData(
    this.profile,
    this.stats,
  );

  final StudentProfile profile;
  final Map<String, dynamic> stats;
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.outline,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: context.colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
    this.label,
    this.value,
  );

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(
    this.label,
    this.icon,
    this.onTap,
  );

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: context.colors.outline,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: context.colors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
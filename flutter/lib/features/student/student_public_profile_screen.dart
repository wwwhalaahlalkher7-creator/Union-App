import 'package:flutter/material.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/app_card.dart';

/// Public profile exposes only fields explicitly allowed by the API.
/// Email, student number, and account/authentication details are never rendered.
class StudentPublicProfileScreen extends StatefulWidget {
  const StudentPublicProfileScreen({super.key, required this.studentId, this.name = '', this.department = '', this.semester = ''});
  final String studentId;
  final String name;
  final String department;
  final String semester;

  @override
  State<StudentPublicProfileScreen> createState() => _StudentPublicProfileScreenState();
}

class _StudentPublicProfileScreenState extends State<StudentPublicProfileScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() => AppDependencies.instance.student.publicProfile(widget.studentId);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name.trim().isEmpty ? l10n.t('publicStudentProfile') : widget.name)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_search_outlined, size: 42, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(l10n.t('studentProfileUnavailable'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.t('retry'))),
            ])));
          }
          final profile = snapshot.data!;
          final name = (profile['fullName'] ?? profile['full_name'] ?? widget.name).toString().trim();
          final department = (profile['departmentName'] ?? profile['department_name'] ?? widget.department).toString().trim();
          final semester = (profile['semesterName'] ?? profile['semester_name'] ?? widget.semester).toString().trim();
          return ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(padding: const EdgeInsets.all(22), child: Column(children: [
              CircleAvatar(radius: 42, backgroundColor: scheme.primaryContainer, child: Icon(Icons.person_rounded, size: 46, color: scheme.onPrimaryContainer)),
              const SizedBox(height: 12),
              Text(name.isEmpty ? l10n.t('publicStudentProfile') : name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              if (department.isNotEmpty) ...[const SizedBox(height: 5), Text(department, textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700))],
              if (semester.isNotEmpty) ...[const SizedBox(height: 4), Text(semester, style: TextStyle(color: scheme.onSurfaceVariant))],
            ])),
            const SizedBox(height: 12),
            AppCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.t('academicInterests'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(l10n.t('profileInterestsPlaceholder'), style: TextStyle(color: scheme.onSurfaceVariant)),
            ])),
            const SizedBox(height: 12),
            AppCard(padding: const EdgeInsets.all(16), child: Row(children: [
              Icon(Icons.forum_outlined, color: scheme.primary), const SizedBox(width: 10),
              Expanded(child: Text(l10n.t('studentMessagingComingSoon'), style: TextStyle(color: scheme.onSurfaceVariant))),
            ])),
          ]);
        },
      ),
    );
  }
}

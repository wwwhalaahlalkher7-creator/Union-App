import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/app_card.dart';

/// Public-facing profile shell. Only explicitly supplied public fields are shown;
/// private account identifiers and contact details are intentionally omitted.
class StudentPublicProfileScreen extends StatelessWidget {
  const StudentPublicProfileScreen({super.key, required this.studentId, this.name = '', this.department = '', this.semester = ''});
  final String studentId;
  final String name;
  final String department;
  final String semester;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(name.trim().isEmpty ? l10n.t('publicStudentProfile') : name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(padding: const EdgeInsets.all(22), child: Column(children: [
          CircleAvatar(radius: 42, backgroundColor: scheme.primaryContainer, child: Icon(Icons.person_rounded, size: 46, color: scheme.onPrimaryContainer)),
          const SizedBox(height: 12),
          Text(name.trim().isEmpty ? l10n.t('publicStudentProfile') : name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          if (department.trim().isNotEmpty) ...[const SizedBox(height: 5), Text(department, textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700))],
          if (semester.trim().isNotEmpty) ...[const SizedBox(height: 4), Text(semester, style: TextStyle(color: scheme.onSurfaceVariant))],
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
      ]),
    );
  }
}

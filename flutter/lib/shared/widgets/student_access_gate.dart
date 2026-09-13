import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_localizations.dart';
import 'app_card.dart';

/// Keeps student-only features explicit instead of waiting for a 401 response.
/// Authentication remains owned by AuthStorage; this widget only decides what
/// should be rendered before a protected repository is initialized.
class StudentAccessGate extends StatefulWidget {
  const StudentAccessGate({required this.child, super.key});

  final Widget child;

  @override
  State<StudentAccessGate> createState() => _StudentAccessGateState();
}

class _StudentAccessGateState extends State<StudentAccessGate> {
  late final Future<bool> _accessFuture = _readAccess();

  Future<bool> _readAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_access_token')?.isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<bool>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.t('studentServices'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) return widget.child;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.t('studentServices'))),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: .11),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_outline_rounded, size: 34, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('studentServicesLockedTitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('studentServicesLockedSubtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.push('/student'),
                      icon: const Icon(Icons.login_rounded),
                      label: Text(l10n.t('signIn')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

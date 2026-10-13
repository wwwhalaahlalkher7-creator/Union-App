import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/storage/auth_storage.dart';
import '../../data/repositories/student_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/utils/academic_labels.dart';
import '../../shared/widgets/action_feedback.dart';

class StudentAccountScreen extends StatefulWidget {
  const StudentAccountScreen({super.key});

  @override
  State<StudentAccountScreen> createState() => _StudentAccountScreenState();
}

class _StudentAccountScreenState extends State<StudentAccountScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final StudentRepository _repo = AppDependencies.instance.student;
  AuthStorage? _storage;
  List<Map<String, dynamic>> _semesters = const [];
  String? _semesterId;
  Map<String, dynamic>? _profile;
  bool _loading = true, _savingSemester = false, _changingPassword = false;
  bool _hideCurrent = true, _hideNew = true, _hideConfirm = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _storage = AppDependencies.instance.authStorage;
      final profile = await _repo.profile();
      final semesters = await _repo.semesters();
      if (!mounted) return;
      setState(() {
        _profile = {
          'name': profile.name,
          'number': profile.number,
          'department': profile.departmentName ?? '—',
          'email': profile.email,
        };
        _semesterId = profile.semesterId;
        _semesters = semesters;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _message(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), true);
      }
    }
  }

  Future<void> _saveSemester() async {
    if (_semesterId == null || _savingSemester) return;
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    setState(() => _savingSemester = true);
    try {
      await AppDependencies.instance.apiClient.postJson(
        '/api/v1/student/semester',
        body: {'semesterId': _semesterId},
      );
      final selected = _semesters.firstWhere(
        (x) => x['id']?.toString() == _semesterId,
        orElse: () => {},
      );
      await _storage?.updateCachedSemester(
        semesterId: _semesterId!,
        semesterName: AcademicLabels.semester(selected, languageCode),
      );
      if (mounted) _message(l10n.t('semesterSaved'), false);
    } catch (e) {
      if (mounted) {
        _message(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), true);
      }
    } finally {
      if (mounted) setState(() => _savingSemester = false);
    }
  }

  Future<void> _changePassword() async {
    if (_changingPassword) return;
    if (_newPassword.text.length < 8) {
      _message(AppLocalizations.of(context).t('passwordTooShortLocal'), true);
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      _message(AppLocalizations.of(context).t('passwordMismatchLocal'), true);
      return;
    }
    setState(() => _changingPassword = true);
    try {
      await AppDependencies.instance.apiClient.postJson(
        '/api/v1/auth/change-password',
        body: {
          'currentPassword': _currentPassword.text,
          'newPassword': _newPassword.text,
          'confirmPassword': _confirmPassword.text,
        },
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      await _storage?.clear();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        _message(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), true);
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _message(String text, bool error) {
    if (!mounted) return;
    if (!error) {
      ActionFeedback.show(context, type: ActionFeedbackType.success);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.6),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('editProfile'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('editProfile')),
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: colors.onPrimaryContainer.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.manage_accounts_rounded, size: 32, color: colors.onPrimaryContainer),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('editProfile'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${_profile?['name'] ?? '—'}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionHeading(context, l10n.t('studentData'), Icons.school_outlined),
                const SizedBox(height: 10),
                _sectionCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _info(context, l10n.t('name'), _profile?['name'], Icons.person_outline_rounded),
                      _info(context, l10n.t('academicId'), _profile?['number'], Icons.badge_outlined),
                      _info(context, l10n.t('department'), _profile?['department'], Icons.account_balance_outlined),
                      _info(
                        context,
                        l10n.t('email'),
                        (_profile?['email'] as String?)?.isNotEmpty == true ? _profile!['email'] : '—',
                        Icons.mail_outline_rounded,
                        isLast: true,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _semesters.any((x) => x['id']?.toString() == _semesterId) ? _semesterId : null,
                        isExpanded: true,
                        items: _semesters.map((x) => DropdownMenuItem(
                          value: x['id']?.toString(),
                          child: Text(
                            AcademicLabels.semester(x, Localizations.localeOf(context).languageCode),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        onChanged: (v) => setState(() => _semesterId = v),
                        decoration: _dec(l10n.t('semester'), Icons.calendar_month_outlined),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _savingSemester ? null : _saveSemester,
                          icon: _savingSemester
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_outlined),
                          label: Text(_savingSemester ? l10n.t('savingSemester') : l10n.t('saveSemester')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _sectionHeading(context, l10n.t('changePassword'), Icons.shield_outlined),
                const SizedBox(height: 10),
                _sectionCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.t('changePasswordHelp'),
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _currentPassword,
                        obscureText: _hideCurrent,
                        autofillHints: const [AutofillHints.password],
                        decoration: _dec(l10n.t('currentPassword'), Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            tooltip: l10n.t(_hideCurrent ? 'showPassword' : 'hidePassword'),
                            icon: Icon(_hideCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newPassword,
                        obscureText: _hideNew,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: _dec(l10n.t('newPassword'), Icons.lock_reset_outlined).copyWith(
                          suffixIcon: IconButton(
                            tooltip: l10n.t(_hideNew ? 'showPassword' : 'hidePassword'),
                            icon: Icon(_hideNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hideNew = !_hideNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPassword,
                        obscureText: _hideConfirm,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: _dec(l10n.t('confirmPassword'), Icons.lock_reset_outlined).copyWith(
                          suffixIcon: IconButton(
                            tooltip: l10n.t(_hideConfirm ? 'showPassword' : 'hidePassword'),
                            icon: Icon(_hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _changingPassword ? null : _changePassword,
                          icon: _changingPassword
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.password_outlined),
                          label: Text(_changingPassword ? l10n.t('changingPassword') : l10n.t('changePassword')),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _changingPassword
                            ? null
                            : () {
                                final number = (_profile?['number'] as String?)?.trim() ?? '';
                                final query = number.isEmpty ? '' : '?studentNumber=${Uri.encodeComponent(number)}';
                                context.push('/forgot-password$query');
                              },
                        icon: const Icon(Icons.lock_reset_outlined),
                        label: Text(l10n.t('forgotPasswordFromSettings')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String title, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 22),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
      ],
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .65)),
        ),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      );

  Widget _info(BuildContext context, String label, dynamic value, IconData icon, {bool isLast = false}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 3),
                SelectableText(
                  '${value ?? '—'}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

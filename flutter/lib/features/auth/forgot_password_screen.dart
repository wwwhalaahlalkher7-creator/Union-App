import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/action_feedback.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({this.initialStudentNumber, super.key});

  final String? initialStudentNumber;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _number = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _sending = false;
  bool _resetting = false;
  bool _sent = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void initState() {
    super.initState();
    _number.text = widget.initialStudentNumber ?? '';
  }

  @override
  void dispose() {
    _number.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _normalizeDigits(String value) {
    return value
        .replaceAllMapped(RegExp(r'[٠-٩]'), (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0x0660 + 0x30))
        .replaceAllMapped(RegExp(r'[۰-۹]'), (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0x06F0 + 0x30))
        .trim();
  }

  Future<void> _request() async {
    final studentNumber = _number.text.trim();
    if (studentNumber.isEmpty) {
      _msg(AppLocalizations.of(context).t('loginFieldsRequired'), true);
      return;
    }
    setState(() => _sending = true);
    try {
      await AppDependencies.instance.apiClient.postJson(
        '/api/v1/auth/forgot-password',
        body: {'studentNumber': studentNumber},
      );
      if (!mounted) return;
      setState(() => _sent = true);
      _msg(AppLocalizations.of(context).t('recoveryCodeSent'), false);
    } catch (e) {
      _msg(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reset() async {
    final code = _normalizeDigits(_code.text);
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _msg(AppLocalizations.of(context).t('recoveryCodeRequired'), true);
      return;
    }
    if (_password.text.length < 8) {
      _msg(AppLocalizations.of(context).t('passwordTooShortLocal'), true);
      return;
    }
    if (_password.text != _confirm.text) {
      _msg(AppLocalizations.of(context).t('passwordMismatchLocal'), true);
      return;
    }

    setState(() => _resetting = true);
    try {
      await AppDependencies.instance.apiClient.postJson(
        '/api/v1/auth/reset-password',
        body: {
          'studentNumber': _number.text.trim(),
          'code': code,
          'newPassword': _password.text,
          'confirmPassword': _confirm.text,
        },
      );
      if (!mounted) return;
      _msg(AppLocalizations.of(context).t('passwordChanged'), false);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) context.go('/login');
      });
    } catch (e) {
      _msg(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), true);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: .35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    );
  }

  void _startOver() {
    if (_sending || _resetting) return;
    setState(() {
      _sent = false;
      _code.clear();
      _password.clear();
      _confirm.clear();
    });
  }

  void _msg(String message, bool error) {
    if (!mounted) return;
    if (!error) {
      ActionFeedback.show(context, type: ActionFeedbackType.success);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('forgotPassword')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(DesignTokens.space16, DesignTokens.space20, DesignTokens.space16, DesignTokens.space32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primaryContainer,
                    ),
                    child: Icon(Icons.lock_reset_rounded, size: 38, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('forgotPassword'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sent
                        ? l10n.t('forgotPasswordSentHelp')
                        : l10n.t('forgotPasswordHelp'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _StepIndicator(currentStep: _sent ? 2 : 1),
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radius20),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionTitle(
                            icon: _sent ? Icons.mark_email_read_outlined : Icons.alternate_email_rounded,
                            title: _sent ? l10n.t('forgotPasswordVerificationTitle') : l10n.t('forgotPasswordRecoveryTitle'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _number,
                            enabled: !_sent,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: _inputDecoration(l10n.t('academicId'), Icons.badge_outlined),
                          ),
                          if (_sent) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer.withValues(alpha: .35),
                                borderRadius: BorderRadius.circular(DesignTokens.radius14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded, color: scheme.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l10n.t('forgotPasswordEmailNotice'),
                                      style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _code,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 7),
                              decoration: _inputDecoration(l10n.t('recoveryCode'), Icons.pin_outlined).copyWith(
                                counterText: '',
                                hintText: '••••••',
                                hintStyle: TextStyle(letterSpacing: 7, color: scheme.onSurfaceVariant.withValues(alpha: .45)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                l10n.t('newPassword'),
                                Icons.lock_reset_outlined,
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword ? l10n.t('forgotPasswordShow') : l10n.t('forgotPasswordHide'),
                                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                  icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirm,
                              obscureText: _hideConfirm,
                              textInputAction: TextInputAction.done,
                              decoration: _inputDecoration(
                                l10n.t('confirmPassword'),
                                Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  tooltip: _hideConfirm ? l10n.t('forgotPasswordShow') : l10n.t('forgotPasswordHide'),
                                  onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                                  icon: Icon(_hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _resetting ? null : _reset,
                                icon: _resetting
                                    ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.check_circle_outline_rounded),
                                label: Text(_resetting ? l10n.t('forgotPasswordSaving') : l10n.t('resetPassword')),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _resetting ? null : _startOver,
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(l10n.t('forgotPasswordUseAnother')),
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _sending ? null : _request,
                                icon: _sending
                                    ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.mark_email_unread_outlined),
                                label: Text(_sending ? l10n.t('forgotPasswordSending') : l10n.t('sendRecoveryCode')),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: (_resetting || _sending) ? null : _request,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.t('forgotPasswordResend')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _Step(number: 1, label: AppLocalizations.of(context).t('forgotPasswordStep1'), active: currentStep >= 1),
        Expanded(child: Divider(color: currentStep >= 2 ? scheme.primary : scheme.outlineVariant, thickness: 1.5)),
        _Step(number: 2, label: AppLocalizations.of(context).t('forgotPasswordStep2'), active: currentStep >= 2),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.label, required this.active});

  final int number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            border: Border.all(color: active ? scheme.primary : scheme.outlineVariant),
          ),
          child: Text('$number', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
      ],
    );
  }
}

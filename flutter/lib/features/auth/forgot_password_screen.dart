import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/auth_storage.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _number = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  ApiClient? _client;
  AuthStorage? _storage;
  Timer? _resendTimer;
  bool _sending = false;
  bool _resetting = false;
  bool _sent = false;
  int _resendSeconds = 0;
  final bool _hide = true;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _number.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    _client?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _storage ??= await AuthStorage.create();
    _client ??= ApiClient(
      baseUrl: AppConstants.apiBaseUrl,
      authStorage: _storage!,
    );
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _request({bool resend = false}) async {
    final l10n = AppLocalizations.of(context);
    if (_number.text.trim().isEmpty) {
      _msg(l10n.t('recoveryRequestFields'), true);
      return;
    }
    if (resend && _resendSeconds > 0) return;

    setState(() => _sending = true);
    try {
      await _init();
      await _client!.postJson(
        '/api/v1/auth/forgot-password',
        body: {'studentNumber': _number.text.trim()},
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _code.clear();
        _password.clear();
        _confirm.clear();
      });
      _startResendCooldown();
      _msg(l10n.t('recoverySent'), false);
    } catch (e) {
      _msg(e is ApiException ? e.message : l10n.t('recoveryGenericError'), true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      _msg(l10n.t('recoveryCodeRequired'), true);
      return;
    }
    if (_password.text.length < 8) {
      _msg(l10n.t('recoveryPasswordRequired'), true);
      return;
    }
    if (_password.text != _confirm.text) {
      _msg(l10n.t('recoveryPasswordMismatch'), true);
      return;
    }

    setState(() => _resetting = true);
    try {
      await _init();
      await _client!.postJson(
        '/api/v1/auth/reset-password',
        body: {
          'studentNumber': _number.text.trim(),
          'code': _code.text.trim(),
          'newPassword': _password.text,
          'confirmPassword': _confirm.text,
        },
      );
      _msg(l10n.t('recoverySuccess'), false);
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) context.go('/login');
      });
    } catch (e) {
      _msg(e is ApiException ? e.message : l10n.t('recoveryGenericError'), true);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  void _msg(String message, bool error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('forgotPassword'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('forgotPasswordHelp'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _number,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.t('academicId'),
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_sent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: l10n.t('recoveryCode'),
                          prefixIcon: const Icon(Icons.pin_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _password,
                        obscureText: _hide,
                        decoration: InputDecoration(
                          labelText: l10n.t('newPassword'),
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirm,
                        obscureText: _hide,
                        decoration: InputDecoration(
                          labelText: l10n.t('confirmPassword'),
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _resetting ? null : _reset,
                        child: Text(
                          _resetting
                              ? l10n.t('recoveryResetting')
                              : l10n.t('resetPassword'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _sending || _resendSeconds > 0
                            ? null
                            : () => _request(resend: true),
                        child: Text(
                          _resendSeconds > 0
                              ? l10n.t(
                                  'recoveryResendWait',
                                  {'seconds': '$_resendSeconds'},
                                )
                              : l10n.t('resendRecoveryCode'),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _sending ? null : _request,
                        child: Text(
                          _sending
                              ? l10n.t('recoverySending')
                              : l10n.t('sendRecoveryCode'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

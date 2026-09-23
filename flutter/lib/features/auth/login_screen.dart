import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/app_preferences.dart';
import '../../core/storage/auth_storage.dart';
import '../../features/eino/eino_face.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/utils/academic_labels.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _performLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    final l10n = AppLocalizations.of(context);

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = l10n.t('loginFieldsRequired'));
      return;
    }
    if (!isValidAcademicId(identifier)) {
      setState(() => _errorMessage = l10n.t('academicIdFormatHelp'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    ApiClient? client;
    try {
      final storage = await AuthStorage.create();
      client = ApiClient(baseUrl: AppConstants.apiBaseUrl, authStorage: storage);

      final response = await client.postJson(
        '/api/v1/auth/login',
        body: {
          'identifier': identifier,
          'studentNumber': identifier,
          'password': password,
        },
      );

      final data = response['data'];
      if (data is! Map) {
        throw ApiException(l10n.t('loginFailed'));
      }

      await storage.saveSession(Map<String, dynamic>.from(data));

      final prefs = AppPreferences();
      await prefs.init();
      await prefs.setOnboardingCompleted(true);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.go('/media');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : l10n.t('loginFailed');
      });
    } finally {
      client?.dispose();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('signIn')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/media');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22.08, vertical: 18.4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Eino Welcome Avatar
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(3.68),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primary.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const EinoFace(size: 88, mood: EinoMood.happy),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    l10n.t('welcomeBack'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.t('studySpaceReady'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Login Form Card
                  AppCard(
                    padding: const EdgeInsets.all(20.24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error Message Display
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(11.04),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(10.8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: theme.colorScheme.onErrorContainer, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Identifier (Student Number or Email)
                        TextField(
                          controller: _identifierController,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: false,
                          ),
                          inputFormatters: const [AcademicIdInputFormatter()],
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.t('studentNumber'),
                            hintText: l10n.t('academicIdHint'),
                            helperText: l10n.t('academicIdFormatHelp'),
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.6)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _performLogin(),
                          decoration: InputDecoration(
                            labelText: l10n.t('password'),
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.6)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _performLogin,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.6)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    l10n.t('signIn'),
                                    style: const TextStyle(
                                        fontSize: 14.7, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Link to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.t('dontHaveAccount'),
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: Text(
                          l10n.t('createAccount'),
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Continue as Guest link
                  Center(
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.go('/media');
                      },
                      child: Text(
                        l10n.t('continueAsGuest'),
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

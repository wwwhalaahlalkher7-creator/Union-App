import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/storage/app_preferences.dart';

/// A short, account-specific interactive walkthrough shown after registration.
/// Guest browsing and returning sign-ins do not route through this screen.
class LearningModeScreen extends StatefulWidget {
  const LearningModeScreen({super.key});

  @override
  State<LearningModeScreen> createState() => _LearningModeScreenState();
}

class _LearningModeScreenState extends State<LearningModeScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = <_LearningStepData>[
    _LearningStepData(
      titleKey: 'learningModeTitle1',
      descriptionKey: 'learningModeDesc1',
      icon: Icons.home_rounded,
    ),
    _LearningStepData(
      titleKey: 'learningModeTitle2',
      descriptionKey: 'learningModeDesc2',
      icon: Icons.menu_book_rounded,
    ),
    _LearningStepData(
      titleKey: 'learningModeTitle3',
      descriptionKey: 'learningModeDesc3',
      icon: Icons.calendar_month_rounded,
    ),
    _LearningStepData(
      titleKey: 'learningModeTitle4',
      descriptionKey: 'learningModeDesc4',
      icon: Icons.psychology_alt_rounded,
    ),
  ];

  late final PageController _pageController = PageController();
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();
  int _currentStep = 0;
  bool _isFinishing = false;

  Future<String> _studentNumber() async {
    return await AppDependencies.instance.authStorage.studentNumber ?? '';
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      final studentNumber = await _studentNumber();
      final preferences = AppPreferences();
      await preferences.init();
      if (studentNumber.isNotEmpty) {
        await preferences.setLearningModeCompletedFor(studentNumber, true);
      }
      if (!mounted) return;
      context.go('/home');
    } catch (error, stackTrace) {
      debugPrint('Could not save learning-mode state: $error\n$stackTrace');
      if (!mounted) return;
      // Do not strand a newly registered student if local persistence fails.
      context.go('/home');
    }
  }

  Future<void> _skipWithConfirmation() async {
    final l10n = AppLocalizations.of(context);
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('learningModeSkipTitle')),
        content: Text(l10n.t('learningModeSkipMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('learningModeKeepGoing')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('learningModeConfirmSkip')),
          ),
        ],
      ),
    );
    if (shouldSkip == true && mounted) await _finish();
  }

  Future<void> _next() async {
    if (_currentStep >= _steps.length - 1) {
      await _finish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_rounded, color: colors.primary, size: 26),
                      const SizedBox(width: 9),
                      Text(
                        'TRINEX',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isFinishing ? null : _skipWithConfirmation,
                        child: Text(l10n.t('learningModeSkip')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('learningModeWelcome'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _steps.length,
                      minHeight: 5,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.t('learningModeStep', {
                      'current': '${_currentStep + 1}',
                      'total': '${_steps.length}',
                    }),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _steps.length,
                      onPageChanged: (index) => setState(() => _currentStep = index),
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return AnimatedBuilder(
                          animation: _entranceController,
                          builder: (context, child) {
                            final progress = reduceMotion
                                ? 1.0
                                : Curves.easeOutCubic.transform(_entranceController.value);
                            return Opacity(
                              opacity: progress,
                              child: Transform.translate(
                                offset: Offset(0, reduceMotion ? 0 : 12 * (1 - progress)),
                                child: child,
                              ),
                            );
                          },
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 156,
                                    height: 156,
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(38),
                                    ),
                                    child: Icon(
                                      step.icon,
                                      size: 76,
                                      color: colors.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    l10n.t(step.titleKey),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.t(step.descriptionKey),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.55,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    children: List.generate(
                                      _steps.length,
                                      (dotIndex) => AnimatedContainer(
                                        duration: const Duration(milliseconds: 220),
                                        width: dotIndex == _currentStep ? 24 : 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: dotIndex == _currentStep
                                              ? colors.primary
                                              : colors.outlineVariant,
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isFinishing ? null : _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isFinishing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _currentStep == _steps.length - 1
                                ? l10n.t('learningModeFinish')
                                : l10n.t('learningModeNext'),
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

class _LearningStepData {
  const _LearningStepData({
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
  });

  final String titleKey;
  final String descriptionKey;
  final IconData icon;
}

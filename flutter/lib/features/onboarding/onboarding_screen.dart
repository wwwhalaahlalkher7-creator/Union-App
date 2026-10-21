import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/storage/app_preferences.dart';
import '../eino/eino_face.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _slideCount = 3;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isNavigating = false;

  bool get _isLastPage => _currentPage == _slideCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeAndGo(String path) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    try {
      final prefs = AppPreferences();
      await prefs.init();
      await prefs.setOnboardingCompleted(true);
      if (!mounted) return;
      context.go(path);
    } catch (_) {
      if (mounted) setState(() => _isNavigating = false);
      rethrow;
    }
  }

  void _goToPage(int page) {
    if (_isNavigating) return;
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showGuestDialog() async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.onPrimaryContainer,
            size: 28,
          ),
        ),
        title: Text(
          l10n.t('guestNoticeTitle'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          l10n.t('guestNoticeDesc'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('understood')),
          ),
        ],
      ),
    );

    if (shouldContinue == true && mounted) {
      await _completeAndGo('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final slides = [
      _OnboardingSlideData(
        title: l10n.t('onboardingTitle1'),
        description: l10n.t('onboardingDesc1'),
        icon: Icons.school_rounded,
        badgeText: 'TRINEX ACADEMIC',
      ),
      _OnboardingSlideData(
        title: l10n.t('onboardingTitle2'),
        description: l10n.t('onboardingDesc2'),
        isEino: true,
        badgeText: 'EINO AI',
      ),
      _OnboardingSlideData(
        title: l10n.t('onboardingTitle3'),
        description: l10n.t('onboardingDesc3'),
        icon: Icons.engineering_rounded,
        badgeText: 'ENGINEERING & COMMUNITY',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      'TRINEX',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_isLastPage)
                    TextButton(
                      onPressed: () => _goToPage(_slideCount - 1),
                      child: Text(l10n.t('skip')),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 490;
                      final visualSize = compact ? 124.0 : 154.0;
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          28,
                          12,
                          28,
                          20,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                                    child: child,
                                  ),
                                ),
                                child: Container(
                                  key: ValueKey(index),
                                  width: visualSize,
                                  height: visualSize,
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.07),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.primary.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Center(
                                    child: slide.isEino
                                        ? EinoFace(
                                            key: const ValueKey('eino-face'),
                                            size: visualSize * 0.76,
                                            mood: EinoMood.happy,
                                          )
                                        : Icon(
                                            slide.icon,
                                            size: visualSize * 0.43,
                                            color: colors.primary,
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 22 : 28),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  slide.badgeText,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.65,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: (compact
                                        ? theme.textTheme.titleLarge
                                        : theme.textTheme.headlineSmall)
                                    ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.28,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 390),
                                child: Text(
                                  slide.description,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.65,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (index) => Semantics(
                    label: '${index + 1} / ${slides.length}',
                    selected: _currentPage == index,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? colors.primary
                            : colors.outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 18),
                child: _isLastPage
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _isNavigating
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      _completeAndGo('/register');
                                    },
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(
                                l10n.t('createAccount'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _isNavigating
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      _completeAndGo('/login');
                                    },
                              icon: const Icon(Icons.login_rounded),
                              label: Text(
                                l10n.t('signIn'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _isNavigating ? null : _showGuestDialog,
                            icon: Icon(
                              isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                              size: 17,
                            ),
                            label: Text(l10n.t('continueAsGuest')),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => _goToPage(_currentPage + 1),
                          icon: Icon(
                            isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            l10n.t('next'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.title,
    required this.description,
    required this.badgeText,
    this.icon = Icons.star_rounded,
    this.isEino = false,
  });

  final String title;
  final String description;
  final String badgeText;
  final IconData icon;
  final bool isEino;
}

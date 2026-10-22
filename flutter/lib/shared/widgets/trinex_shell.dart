import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../features/eino/eino_face.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/storage/app_preferences.dart';
import '../../features/onboarding/guided_tour_overlay.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../data/models/notification_item.dart';

class TrinexShell extends StatefulWidget {
  const TrinexShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  State<TrinexShell> createState() => _TrinexShellState();
}

class _TrinexShellState extends State<TrinexShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  late final AnimationController _transitionController = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 940),
  );
  bool _einoTransitionRunning = false;
  bool _showEinoTransition = false;
  bool _isReturningEino = false;
  bool _reduceMotion = false;
  Timer? _pulseIdleTimer;

  bool _einoVisible = false;
  int _unreadNotifications = 0;
  StreamSubscription<void>? _notificationSubscription;
  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _feedbackOpening = false;
  int? _guidedTourStep;
  bool _guidedTourActionRunning = false;
  bool _guidedTourCheckRunning = false;
  bool _guidedTourCheckRequested = false;

  bool get _readingMode => widget.location == '/media/detail';

  bool get _hideFloatingEino => widget.location.startsWith('/student') || widget.location.startsWith('/eino');

  void _schedulePulseIdle() {
    _pulseIdleTimer?.cancel();
    if (_reduceMotion) {
      _pulse.stop(canceled: false);
      return;
    }
    _pulse.repeat();
    _pulseIdleTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) _pulse.stop(canceled: false);
    });
  }

  Future<void> _openEinoWithTransition() async {
    if (_einoTransitionRunning || !mounted) return;
    _einoTransitionRunning = true;
    _pulseIdleTimer?.cancel();
    _pulse.repeat();
    try {
      if (!_reduceMotion) {
        setState(() {
          _isReturningEino = false;
          _showEinoTransition = true;
        });
        await _transitionController.forward(from: 0);
        if (!mounted) return;
        setState(() => _showEinoTransition = false);
      }
      // The floating orb is hidden in chat; stop its shell glow while the
      // chat screen owns the visible Eino animation.
      _pulse.stop(canceled: false);
      await context.push('/eino?from=shell');
      if (!mounted) return;
      _pulse.repeat();
      if (!_reduceMotion) {
        // Return is a new forward animation with its own easing curve, not a
        // literal reverse of the entry timeline. It contracts quickly first,
        // then settles softly into the floating-button position.
        setState(() {
          _isReturningEino = true;
          _showEinoTransition = true;
        });
        await _transitionController.forward(from: 0);
        if (!mounted) return;
        setState(() {
          _showEinoTransition = false;
          _isReturningEino = false;
        });
        // The floating orb must return to its normal motion profile after the
        // full-screen return animation has settled.
        _transitionController.value = 0;
      }
      _schedulePulseIdle();
    } finally {
      _isReturningEino = false;
      _einoTransitionRunning = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _pulseIdleTimer?.cancel();
      _pulse.stop(canceled: false);
      _transitionController.stop(canceled: false);
    } else if (mounted) {
      _schedulePulseIdle();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startShakeDetection();
    _notificationSubscription = PushNotificationService.instance.notificationArrived.listen((_) => _handleNotificationArrived());
    _einoVisible = !_readingMode && !_hideFloatingEino;
    FocusManager.instance.addListener(_handleFocusChange);
    _refreshUnreadNotifications();
    _schedulePulseIdle();
    _checkPendingGuidedTour();
  }

  Future<void> _checkPendingGuidedTour() async {
    if (_guidedTourCheckRunning || _guidedTourStep != null) {
      _guidedTourCheckRequested = true;
      return;
    }
    _guidedTourCheckRunning = true;
    _guidedTourCheckRequested = false;
    try {
      final authStorage = AppDependencies.instance.authStorage;
      final profile = await authStorage.profile;
      final studentNumber = ((profile?['studentNumber'] ?? await authStorage.studentNumber) ?? '').toString().trim();
      if (studentNumber.isEmpty) return; // Guests never see the guided tour.
      final preferences = AppPreferences();
      await preferences.init();
      if (!preferences.learningModePendingFor(studentNumber) ||
          preferences.learningModeCompletedFor(studentNumber)) {
        return;
      }

      // Wait for the real home content to render before placing the spotlight.
      var targetReady = false;
      for (var attempt = 0; attempt < 100; attempt++) {
        if (!mounted) return;
        final targetContext = guidedTourHomeNavKey.currentContext;
        final targetObject = targetContext?.findRenderObject();
        if (targetObject is RenderBox && targetObject.hasSize) {
          targetReady = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (!mounted) return;
      if (widget.location != '/home' || !targetReady) {
        _guidedTourCheckRequested = widget.location != '/home' || !targetReady;
        return;
      }
      setState(() => _guidedTourStep = 0);
    } catch (error, stackTrace) {
      debugPrint('Could not initialize guided tour: $error\n$stackTrace');
    } finally {
      _guidedTourCheckRunning = false;
      if (mounted && _guidedTourCheckRequested && widget.location == '/home' && _guidedTourStep == null) {
        _guidedTourCheckRequested = false;
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) unawaited(_checkPendingGuidedTour()); });
      }
    }
  }

  Future<void> _onGuidedTourTargetTap() async {
    if (_guidedTourActionRunning || _guidedTourStep == null || !mounted) return;
    _guidedTourActionRunning = true;
    final step = _guidedTourStep!;
    try {
      switch (step) {
        case 0:
          // The highlighted destination is the real Home navigation item.
          context.go('/home');
          setState(() => _guidedTourStep = 1);
          break;
        case 1:
          // Perform the same action as the highlighted schedule card.
          context.push('/schedule');
          setState(() => _guidedTourStep = 2);
          break;
        case 2:
          context.go('/materials');
          setState(() => _guidedTourStep = 3);
          break;
        case 3:
          context.go('/media');
          setState(() => _guidedTourStep = 4);
          break;
        case 4:
          context.go('/more');
          setState(() => _guidedTourStep = 5);
          break;
        case 5:
          await _completeGuidedTour();
          if (mounted) await _openEinoWithTransition();
          break;
      }
    } finally {
      _guidedTourActionRunning = false;
    }
  }

  Future<void> _skipGuidedTour() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('guidedTourSkipTitle')),
        content: Text(l10n.t('guidedTourSkipMessage')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.t('guidedTourKeepGoing'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.t('guidedTourConfirmSkip'))),
        ],
      ),
    );
    if (confirmed == true) await _completeGuidedTour();
  }

  Future<void> _completeGuidedTour() async {
    try {
      final studentNumber = (await AppDependencies.instance.authStorage.studentNumber)?.trim() ?? '';
      if (studentNumber.isNotEmpty) {
        final preferences = AppPreferences();
        await preferences.init();
        await preferences.setLearningModeCompletedFor(studentNumber, true);
        await preferences.setLearningModePendingFor(studentNumber, false);
      }
    } catch (error, stackTrace) {
      // Never block app access if local preference storage is unavailable.
      debugPrint('Could not persist guided-tour completion: $error\n$stackTrace');
    } finally {
      if (mounted) setState(() => _guidedTourStep = null);
    }
  }

  @override
  void didUpdateWidget(covariant TrinexShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location && widget.location == '/home' && _guidedTourStep == null) {
      // Registration may finish while the shell already exists; always retry
      // after the home route has completed its first layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_checkPendingGuidedTour());
      });
    }
    if ((oldWidget.location.startsWith('/notifications') && !widget.location.startsWith('/notifications')) ||
        (oldWidget.location.startsWith('/login') && widget.location.startsWith('/home'))) {
      _refreshUnreadNotifications();
    }
    if (oldWidget.location != widget.location && _readingMode) {
      _einoVisible = false;
    } else if (oldWidget.location != widget.location && !_readingMode) {
      _einoVisible = !_hideFloatingEino;
    }
  }

  void _handleFocusChange() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final isEditing =
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!mounted) return;
    if (isEditing && _einoVisible) {
      setState(() => _einoVisible = false);
    } else if (!isEditing && !_einoVisible && !_readingMode && !_hideFloatingEino) {
      setState(() => _einoVisible = true);
    }
  }

  void _handleNotificationArrived() {
    if (!mounted) return;
    setState(() => _unreadNotifications += 1);
  }

  Future<void> _refreshUnreadNotifications() async {
    try {
      final items = await AppDependencies.instance.notifications.list();
      if (!mounted) return;
      setState(() => _unreadNotifications = items.where((NotificationItem item) => !item.isRead).length);
    } catch (_) {
      // Signed-out visitors see no badge; failures do not trigger repeated requests.
      if (mounted) setState(() => _unreadNotifications = 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startShakeDetection();
      if (!_einoTransitionRunning) _schedulePulseIdle();
    } else {
      _stopShakeDetection();
      _pulseIdleTimer?.cancel();
      _pulse.stop(canceled: false);
      _transitionController.stop(canceled: false);
    }
  }

  void _startShakeDetection() {
    if (_shakeSubscription != null) return;
    _shakeSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen(
      _handleAccelerometerEvent,
      onError: (_) => _stopShakeDetection(),
      cancelOnError: true,
    );
  }

  void _stopShakeDetection() {
    final subscription = _shakeSubscription;
    _shakeSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    if (!mounted || _feedbackOpening) return;
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    // A brisk movement beyond gravity is enough; the cooldown prevents a
    // single shake from pushing multiple feedback routes.
    if (magnitude < 18) return;
    final now = DateTime.now();
    if (now.difference(_lastShakeAt) < const Duration(seconds: 2)) return;
    _lastShakeAt = now;
    _feedbackOpening = true;
    unawaited(
      context.push('/feedback').then<void>(
        (_) => _feedbackOpening = false,
        onError: (Object _) => _feedbackOpening = false,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopShakeDetection();
    _notificationSubscription?.cancel();
    FocusManager.instance.removeListener(_handleFocusChange);
    _pulseIdleTimer?.cancel();
    _pulse.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  int get index {
    if (widget.location.startsWith('/more')) return 0;
    if (widget.location.startsWith('/media')) return 1;
    if (widget.location.startsWith('/materials')) return 2;
    if (widget.location.startsWith('/home')) return 3;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: Column(
          children: [
            _TopHeader(unreadNotifications: _unreadNotifications),
            Expanded(
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth >= 1100 ? 1040.0 : constraints.maxWidth;
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: widget.child,
                        ),
                      );
                    },
                  ),
                  if (_einoVisible)
                    PositionedDirectional(
                      end: 16,
                      bottom: 18,
                      child: KeyedSubtree(
                        key: guidedTourEinoKey,
                        child: EinoFloatingButton(animation: _pulse, transitionAnimation: _transitionController, onTap: _openEinoWithTransition),
                      ),
                    ),
                  // A narrow edge gesture lets the student summon Eino again
                  // without adding another permanent button to the UI.
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: 24,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: (details) {
                        final rtl = Directionality.of(context) == TextDirection.rtl;
                        final velocity = details.primaryVelocity ?? 0;
                        final summoned = rtl ? velocity < -350 : velocity > 350;
                        if (summoned && !_einoVisible && mounted) {
                          setState(() => _einoVisible = true);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            _MainNav(selected: index),
            const SizedBox(height: 4),
          ],
            ),
          ),
          if (_showEinoTransition && !_reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _transitionController,
                  builder: (context, _) {
                    final raw = _transitionController.value;
                    final t = _isReturningEino
                        ? (1 - Curves.easeOutQuart.transform(raw)).clamp(0.0, 1.0).toDouble()
                        : Curves.easeInOutCubic.transform(raw);
                    final startAlignment = AlignmentDirectional.bottomEnd.resolve(Directionality.of(context));
                    final alignment = Alignment.lerp(
                      startAlignment,
                      Alignment.center,
                      t,
                    )!;
                    final scale = 1 + (7.2 * t);
                    final opacity = (t * .92).clamp(0.0, .92).toDouble();
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: opacity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: alignment,
                                radius: 1.05,
                                colors: [
                                  Theme.of(context).colorScheme.primary.withValues(alpha: .55),
                                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .72),
                                  Theme.of(context).colorScheme.surface.withValues(alpha: .94),
                                ],
                                stops: const [0, .42, 1],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: alignment,
                          child: Transform.scale(
                            scale: scale,
                            child: EinoFace(
                              size: 92,
                              mood: EinoMood.curious,
                              showAura: true,
                              motionBoost: _isReturningEino ? 1 - raw : raw,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          if (_guidedTourStep != null)
            Positioned.fill(
              child: GuidedTourOverlay(
                stepIndex: _guidedTourStep!,
                onTargetTap: _onGuidedTourTargetTap,
                onSkip: _skipGuidedTour,
              ),
            ),
        ],
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.unreadNotifications});

  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .96),
        border: Border(
          bottom: BorderSide(color: context.colors.outlineVariant.withValues(alpha: .62)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 600;
          final button = compact ? 48.0 : 52.0;
          final avatar = compact ? 42.0 : 46.0;
          final logo = compact ? 48.0 : 52.0;
          final primary = context.colors.primary;

          // The header is intentionally LTR so its physical layout stays
          // consistent in the Arabic UI:
          // left  -> TRINEX + app icon (app icon opens Settings)
          // right -> profile + System
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                // Left side: tappable application icon + brand name.
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    onTap: () => context.push('/settings'),
                    child: Tooltip(
                      message: l10n.t('settings'),
                      child: Container(
                        width: logo,
                        height: logo,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(DesignTokens.radius14),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: .18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icons/trinex_icon.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'TRINEX',
                  style: TextStyle(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),
                const Spacer(),
                // Right side: notifications + profile.
                _HeaderIcon(
                  icon: Icons.notifications_none_rounded,
                  size: button,
                  tooltip: l10n.t('notifications'),
                  badgeCount: unreadNotifications,
                  onTap: () => context.push('/notifications'),
                ),
                const SizedBox(width: 4),
                _Avatar(
                  size: avatar,
                  onTap: () => context.go('/student'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MainNav extends StatelessWidget {
  const _MainNav({required this.selected});

  final int selected;

  static const items = [
    ('navMore', Icons.grid_view_rounded, '/more'),
    ('navMedia', Icons.campaign_outlined, '/media'),
    ('navMaterials', Icons.menu_book_outlined, '/materials'),
    ('navHome', Icons.home_outlined, '/home'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(DesignTokens.radius20),
          border: Border.all(color: context.colors.outlineVariant.withValues(alpha: .72)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .16 : .06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selected < 0 ? 0 : selected.clamp(0, items.length - 1),
          height: 68,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: context.colors.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => context.go(items[i].$3),
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: KeyedSubtree(
                  key: item.$3 == '/materials'
                      ? guidedTourMaterialsKey
                      : item.$3 == '/media'
                          ? guidedTourMediaKey
                          : item.$3 == '/more'
                              ? guidedTourMoreKey
                              : item.$3 == '/home'
                                  ? guidedTourHomeNavKey
                                  : null,
                  child: Icon(item.$2),
                ),
                selectedIcon: Icon(item.$2),
                label: l10n.t(item.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.size = 48,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(clipBehavior: Clip.none, children: [
              Center(child: Icon(icon, color: context.colors.onSurface, size: 29)),
              if (badgeCount > 0)
                Positioned(
                  top: 3,
                  left: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(badgeCount > 99 ? '99+' : '$badgeCount', textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.size = 50, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.t('profile'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.surfaceContainerHigh,
            border: Border.all(
              color: context.colors.outlineVariant,
              width: 1.2,
            ),
          ),
          child: Icon(
            Icons.account_circle_rounded,
            color: context.colors.primary,
            size: size * .84,
          ),
        ),
      ),
    );
  }
}

class EinoFloatingButton extends StatelessWidget {
  const EinoFloatingButton({required this.animation, required this.transitionAnimation, required this.onTap, super.key});

  final Animation<double> animation;
  final Animation<double> transitionAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final glow =
            .12 + (.10 * (0.5 + 0.5 * (animation.value * 2 - 1).abs()));
        return AnimatedBuilder(
          animation: transitionAnimation,
          builder: (context, _) => Semantics(
          button: true,
          label: 'Eino',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: primary.withValues(alpha: .12),
              highlightColor: primary.withValues(alpha: .06),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: glow),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: EinoFace(
                  size: 76,
                  mood: EinoMood.calm,
                  motionBoost: transitionAnimation.value,
                ),
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

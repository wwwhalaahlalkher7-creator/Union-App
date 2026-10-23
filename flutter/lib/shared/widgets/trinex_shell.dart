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
    vsync: this,
    duration: const Duration(milliseconds: 580),
  );
  late final AnimationController _handoffController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 190),
  );
  final GlobalKey _einoButtonKey = GlobalKey();
  OverlayEntry? _einoTransitionEntry;
  bool _einoTransitionRunning = false;
  bool _isEinoTransitioning = false;
  bool _isEinoReturning = false;
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

  Rect? _measureEinoButtonRect(OverlayState overlay) {
    final buttonObject = _einoButtonKey.currentContext?.findRenderObject();
    final overlayObject = overlay.context.findRenderObject();
    if (buttonObject is! RenderBox ||
        overlayObject is! RenderBox ||
        !buttonObject.hasSize ||
        !overlayObject.hasSize) {
      return null;
    }
    final globalOrigin = buttonObject.localToGlobal(Offset.zero);
    final localOrigin = overlayObject.globalToLocal(globalOrigin);
    final rect = localOrigin & buttonObject.size;
    if (rect.width <= 0 || rect.height <= 0) return null;
    return rect;
  }

  Size? _rootOverlaySize(OverlayState overlay) {
    final object = overlay.context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    return object.size;
  }

  OverlayEntry _buildEinoTransitionEntry({
    required OverlayState overlay,
    required Rect from,
    required Rect to,
    required bool returning,
  }) {
    return OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: Listenable.merge([
          _transitionController,
          _handoffController,
        ]),
        builder: (context, _) {
          final progress = Curves.easeInOutCubic.transform(
            _transitionController.value.clamp(0.0, 1.0).toDouble(),
          );
          final handoff = returning
              ? 0.0
              : Curves.easeOutCubic.transform(_handoffController.value);
          final routeVeilOpacity = returning ? 1.0 : (1.0 - handoff);
          final orbOpacity = returning
              ? 1.0 - Curves.easeInOutCubic.transform(
                  ((progress - .93) / .07).clamp(0.0, 1.0).toDouble(),
                )
              : Curves.easeInOutCubic.transform(
                  (progress / .07).clamp(0.0, 1.0).toDouble(),
                );
          final backdropProgress = returning ? 1.0 - progress : progress;
          final backdropOpacity = (backdropProgress * .99 * routeVeilOpacity)
              .clamp(0.0, .99)
              .toDouble();
          final rect = Rect.lerp(from, to, progress)!;
          final center = rect.center;
          final overlaySize = _rootOverlaySize(overlay) ?? MediaQuery.sizeOf(context);
          final alignment = Alignment(
            ((center.dx / overlaySize.width) * 2 - 1)
                .clamp(-1.0, 1.0)
                .toDouble(),
            ((center.dy / overlaySize.height) * 2 - 1)
                .clamp(-1.0, 1.0)
                .toDouble(),
          );
          final orbSize = rect.shortestSide;
          final motionBoost = math.sin(progress * math.pi).clamp(0.0, 1.0).toDouble();
          final colorScheme = Theme.of(context).colorScheme;

          return IgnorePointer(
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  if (backdropOpacity > 0.001)
                    Positioned.fill(
                      child: Opacity(
                        opacity: backdropOpacity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: alignment,
                              radius: 1.35,
                              colors: [
                                colorScheme.primary.withValues(alpha: .30),
                                colorScheme.surfaceContainerHighest.withValues(alpha: .96),
                                colorScheme.surface,
                              ],
                              stops: const [0, .43, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fromRect(
                    rect: rect,
                    child: Opacity(
                      opacity: (routeVeilOpacity * orbOpacity)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                      child: Center(
                        child: EinoFace(
                          size: orbSize,
                          mood: EinoMood.calm,
                          showAura: true,
                          motionBoost: motionBoost,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _playEinoTransition({
    required OverlayState overlay,
    required Rect from,
    required Rect to,
    required bool returning,
  }) async {
    _transitionController.duration = Duration(
      milliseconds: returning ? 460 : 580,
    );
    _handoffController.value = 0;
    final entry = _buildEinoTransitionEntry(
      overlay: overlay,
      from: from,
      to: to,
      returning: returning,
    );
    _einoTransitionEntry = entry;
    overlay.insert(entry);
    try {
      await _transitionController.forward(from: 0).orCancel;
      return true;
    } on TickerCanceled {
      return false;
    }
  }

  void _removeEinoTransitionEntry() {
    final entry = _einoTransitionEntry;
    _einoTransitionEntry = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  Future<void> _openEinoWithTransition() async {
    if (_einoTransitionRunning || !mounted) return;
    _einoTransitionRunning = true;
    _pulseIdleTimer?.cancel();

    OverlayState? overlay;
    Rect? buttonRect;
    Size? overlaySize;
    try {
      overlay = Overlay.of(context, rootOverlay: true);
      buttonRect = _measureEinoButtonRect(overlay);
      overlaySize = _rootOverlaySize(overlay);
    } catch (_) {
      // If the element cannot be measured, use the normal route transition.
    }

    final canAnimate = !_reduceMotion &&
        overlay != null &&
        buttonRect != null &&
        overlaySize != null &&
        overlaySize.shortestSide > 0;
    var routeReturned = true;
    try {
      _pulse.stop(canceled: false);
      if (!canAnimate) {
        await context.push<void>('/eino?from=shell');
        return;
      }

      setState(() => _isEinoTransitioning = true);
      final currentOverlay = overlay!;
      final sourceRect = buttonRect!;
      final size = overlaySize!;
      final centerDiameter = math
          .min(math.max(size.shortestSide * .22, 128.0), 156.0)
          .toDouble();
      final centerRect = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: centerDiameter,
        height: centerDiameter,
      );

      final entered = await _playEinoTransition(
        overlay: currentOverlay,
        from: sourceRect,
        to: centerRect,
        returning: false,
      );
      if (!mounted) return;
      if (!entered || _reduceMotion) {
        _removeEinoTransitionEntry();
        setState(() => _isEinoTransitioning = false);
        await context.push<void>('/eino?from=shell');
        return;
      }

      // Push the destination while the transition veil covers the route's
      // platform animation. Fade the veil away only after the chat is mounted.
      final routeFuture = context.push<void>('/eino?from=shell');
      routeReturned = false;
      await Future<void>.delayed(const Duration(milliseconds: 125));
      if (!_reduceMotion) {
        try {
          await _handoffController.forward(from: 0).orCancel;
        } on TickerCanceled {
          // Reduced-motion settings may change while the route is opening.
        }
      }
      _removeEinoTransitionEntry();
      // Keep the source orb hidden under the chat route and reveal it only as
      // the return transition reaches its final frames.
      _isEinoReturning = true;
      _transitionController.value = 0;
      _handoffController.value = 0;
      await routeFuture;
      routeReturned = true;
      if (!mounted) return;

      if (!_reduceMotion) {
        // Measure the actual button again after the route is popped. The shell
        // keeps the button mounted (but transparent) during the chat route.
        final returnRect = _measureEinoButtonRect(currentOverlay);
        final currentSize = _rootOverlaySize(currentOverlay);
        if (returnRect != null && currentSize != null) {
          final returnCenterDiameter = math
              .min(math.max(currentSize.shortestSide * .22, 128.0), 156.0)
              .toDouble();
          final returnCenter = Rect.fromCenter(
            center: currentSize.center(Offset.zero),
            width: returnCenterDiameter,
            height: returnCenterDiameter,
          );
          await _playEinoTransition(
            overlay: currentOverlay,
            from: returnCenter,
            to: returnRect,
            returning: true,
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Eino transition failed; using the stable route state: $error\n$stackTrace');
    } finally {
      _removeEinoTransitionEntry();
      if (mounted) {
        _transitionController.value = 0;
        _handoffController.value = 0;
        if (_isEinoTransitioning || _isEinoReturning) {
          setState(() {
            _isEinoTransitioning = false;
            _isEinoReturning = false;
          });
        }
        if (routeReturned) _schedulePulseIdle();
      }
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
      _transitionController.stop(canceled: true);
      _handoffController.stop(canceled: true);
      _removeEinoTransitionEntry();
      _isEinoTransitioning = false;
      _isEinoReturning = false;
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
      // Cancel in-flight transitions so their awaited ticker futures settle;
      // otherwise an app switch mid-animation could leave the veil frozen.
      _transitionController.stop(canceled: true);
      _handoffController.stop(canceled: true);
      _removeEinoTransitionEntry();
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
    _removeEinoTransitionEntry();
    _pulse.dispose();
    _transitionController.dispose();
    _handoffController.dispose();
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
                  if (_einoVisible || _isEinoTransitioning)
                    PositionedDirectional(
                      end: 16,
                      bottom: 18,
                      child: KeyedSubtree(
                        key: guidedTourEinoKey,
                        child: AnimatedBuilder(
                          animation: _transitionController,
                          builder: (context, _) {
                            final progress = _transitionController.value;
                            final sourceFade = !_isEinoTransitioning
                                ? 1.0
                                : _isEinoReturning
                                    ? Curves.easeInOutCubic.transform(
                                        ((progress - .93) / .07)
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                      )
                                    : 1.0 - Curves.easeInOutCubic.transform(
                                        (progress / .07)
                                            .clamp(0.0, 1.0)
                                            .toDouble(),
                                      );
                            return Opacity(
                              opacity: sourceFade,
                              child: IgnorePointer(
                                ignoring: _isEinoTransitioning,
                                child: SizedBox(
                                  // Put the key on a real 76×76 RenderBox so
                                  // measurement cannot resolve to a parent Stack.
                                  key: _einoButtonKey,
                                  width: 76,
                                  height: 76,
                                  child: EinoFloatingButton(
                                    animation: _pulse,
                                    transitionAnimation: _transitionController,
                                    onTap: _openEinoWithTransition,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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

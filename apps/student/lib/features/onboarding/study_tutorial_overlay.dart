import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

/// Real UI anchors used by the post-registration spotlight tour.
/// These keys are attached to the profile, Materials destination and Eino orb
/// rendered by the shell, rather than to placeholder illustrations.
class StudyTutorialTargets {
  StudyTutorialTargets._();

  static final GlobalKey profile = GlobalKey(debugLabel: 'study-tour-profile');
  static final GlobalKey materials = GlobalKey(debugLabel: 'study-tour-materials');
  static final GlobalKey eino = GlobalKey(debugLabel: 'study-tour-eino');
}

/// A first-registration-only guided overlay shown above the real app shell.
/// It deliberately differs from the three-page pre-login onboarding flow.
class StudyTutorialOverlay extends StatefulWidget {
  const StudyTutorialOverlay({super.key, required this.onFinish, required this.onSkip});

  final VoidCallback onFinish;
  final VoidCallback onSkip;

  @override
  State<StudyTutorialOverlay> createState() => _StudyTutorialOverlayState();
}

class _StudyTutorialOverlayState extends State<StudyTutorialOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _overlayStackKey = GlobalKey(debugLabel: 'study-tour-overlay-stack');
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  int _step = 0;
  Rect? _targetRect;

  static const _icons = <IconData>[
    Icons.auto_awesome_rounded,
    Icons.account_circle_rounded,
    Icons.menu_book_rounded,
    Icons.bubble_chart_rounded,
  ];

  static const _titles = <String>[
    'studyTourWelcomeTitle',
    'studyTourProfileTitle',
    'studyTourMaterialsTitle',
    'studyTourEinoTitle',
  ];

  static const _bodies = <String>[
    'studyTourWelcomeBody',
    'studyTourProfileBody',
    'studyTourMaterialsBody',
    'studyTourEinoBody',
  ];

  GlobalKey? get _targetKey => switch (_step) {
        1 => StudyTutorialTargets.profile,
        2 => StudyTutorialTargets.materials,
        3 => StudyTutorialTargets.eino,
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  void _measureTarget() {
    if (!mounted) return;
    final targetContext = _targetKey?.currentContext;
    final stackContext = _overlayStackKey.currentContext;
    final targetObject = targetContext?.findRenderObject();
    final stackObject = stackContext?.findRenderObject();
    if (targetObject is! RenderBox || stackObject is! RenderBox ||
        !targetObject.hasSize || !stackObject.hasSize) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }

    // The target and dialog belong to different Navigator entries. Convert both
    // origins to global coordinates, then express the target relative to this Stack.
    final targetGlobal = targetObject.localToGlobal(Offset.zero);
    final stackGlobal = stackObject.localToGlobal(Offset.zero);
    final rect = (targetGlobal - stackGlobal) & targetObject.size;
    final bounds = Offset.zero & stackObject.size;
    final clipped = rect.intersect(bounds);
    if (_targetRect != clipped) setState(() => _targetRect = clipped);
  }

  void _changeStep(int next) {
    setState(() {
      _step = next.clamp(0, _titles.length - 1).toInt();
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final last = _step == _titles.length - 1;

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.20),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Transform.scale(
                scale: 0.94 + (_pulse.value * 0.08),
                child: child,
              ),
              child: Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.32),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(_icons[_step], size: 44, color: colors.onPrimary),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.t(_titles[_step]),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t(_bodies[_step]),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.55,
                  ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_titles.length, (index) {
                final selected = index == _step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 24 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: selected ? colors.primary : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _changeStep(_step - 1),
                      child: Text(l10n.t('back')),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (last) {
                        widget.onFinish();
                      } else {
                        _changeStep(_step + 1);
                      }
                    },
                    icon: Icon(last ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded),
                    label: Text(l10n.t(last ? 'getStarted' : 'next')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final targetIsHigh = _targetRect != null &&
                _targetRect!.center.dy < constraints.maxHeight / 2;
            return Stack(
              key: _overlayStackKey,
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => CustomPaint(
                      painter: _TutorialSpotlightPainter(
                        target: _targetRect,
                        accent: colors.primary,
                        pulse: _pulse.value,
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 8,
                  start: 12,
                  child: TextButton(
                    onPressed: widget.onSkip,
                    child: Text(l10n.t('skip'), style: const TextStyle(color: Colors.white)),
                  ),
                ),
                if (_step == 0)
                  Center(child: Padding(padding: const EdgeInsets.all(22), child: card))
                else if (targetIsHigh)
                  PositionedDirectional(
                    start: 18,
                    end: 18,
                    bottom: 82,
                    child: Center(child: SingleChildScrollView(child: card)),
                  )
                else
                  PositionedDirectional(
                    start: 18,
                    end: 18,
                    top: 76,
                    child: Center(child: SingleChildScrollView(child: card)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TutorialSpotlightPainter extends CustomPainter {
  const _TutorialSpotlightPainter({required this.target, required this.accent, required this.pulse});

  final Rect? target;
  final Color accent;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final path = Path()..addRect(screen);
    final rect = target;
    if (rect != null && rect.width > 1 && rect.height > 1) {
      path.addRRect(RRect.fromRectAndRadius(rect.inflate(9), const Radius.circular(18)));
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, dim);

    if (rect == null || rect.width <= 1 || rect.height <= 1) return;
    final radius = RRect.fromRectAndRadius(rect.inflate(9 + pulse * 3), const Radius.circular(18));
    canvas.drawRRect(
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + pulse
        ..color = Color.lerp(Colors.white, accent, pulse * 0.55)!.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(13 + pulse * 5), const Radius.circular(22)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.22 + pulse * 0.20),
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialSpotlightPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.accent != accent || oldDelegate.pulse != pulse;
}

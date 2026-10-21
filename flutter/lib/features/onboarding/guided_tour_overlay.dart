import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

/// Global anchors are attached to real TRINEX widgets. The tour measures these
/// widgets at runtime, so the spotlight follows RTL, themes and screen sizes.
final GlobalKey guidedTourHomeNavKey = GlobalKey(debugLabel: 'tour-nav-home');
final GlobalKey guidedTourScheduleKey = GlobalKey(debugLabel: 'tour-home-schedule');
final GlobalKey guidedTourMaterialsKey = GlobalKey(debugLabel: 'tour-nav-materials');
final GlobalKey guidedTourMediaKey = GlobalKey(debugLabel: 'tour-nav-media');
final GlobalKey guidedTourMoreKey = GlobalKey(debugLabel: 'tour-nav-more');
final GlobalKey guidedTourEinoKey = GlobalKey(debugLabel: 'tour-floating-eino');

class GuidedTourStep {
  const GuidedTourStep({
    required this.targetKey,
    required this.titleKey,
    required this.descriptionKey,
    required this.hintKey,
  });

  final GlobalKey targetKey;
  final String titleKey;
  final String descriptionKey;
  final String hintKey;
}

final List<GuidedTourStep> guidedTourSteps = [
  GuidedTourStep(targetKey: guidedTourHomeNavKey, titleKey: 'guidedTourHomeTitle', descriptionKey: 'guidedTourHomeDesc', hintKey: 'guidedTourTapHint'),
  GuidedTourStep(targetKey: guidedTourScheduleKey, titleKey: 'guidedTourScheduleTitle', descriptionKey: 'guidedTourScheduleDesc', hintKey: 'guidedTourTapHint'),
  GuidedTourStep(targetKey: guidedTourMaterialsKey, titleKey: 'guidedTourMaterialsTitle', descriptionKey: 'guidedTourMaterialsDesc', hintKey: 'guidedTourTapHint'),
  GuidedTourStep(targetKey: guidedTourMediaKey, titleKey: 'guidedTourMediaTitle', descriptionKey: 'guidedTourMediaDesc', hintKey: 'guidedTourTapHint'),
  GuidedTourStep(targetKey: guidedTourMoreKey, titleKey: 'guidedTourMoreTitle', descriptionKey: 'guidedTourMoreDesc', hintKey: 'guidedTourTapHint'),
  GuidedTourStep(targetKey: guidedTourEinoKey, titleKey: 'guidedTourEinoTitle', descriptionKey: 'guidedTourEinoDesc', hintKey: 'guidedTourTapHint'),
];

class GuidedTourOverlay extends StatefulWidget {
  const GuidedTourOverlay({
    required this.stepIndex,
    required this.onTargetTap,
    required this.onSkip,
    super.key,
  });

  final int stepIndex;
  final VoidCallback onTargetTap;
  final VoidCallback onSkip;

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay> {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant GuidedTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepIndex != widget.stepIndex) _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  void _measureTarget() {
    if (!mounted) return;
    final key = guidedTourSteps[widget.stepIndex].targetKey;
    final targetContext = key.currentContext;
    final overlayObject = context.findRenderObject();
    final targetObject = targetContext?.findRenderObject();
    if (targetObject is! RenderBox || !targetObject.hasSize ||
        overlayObject is! RenderBox || !overlayObject.hasSize) {
      setState(() => _targetRect = null);
      return;
    }
    final globalTopLeft = targetObject.localToGlobal(Offset.zero);
    final topLeft = overlayObject.globalToLocal(globalTopLeft);
    final rect = topLeft & targetObject.size;
    final isNavigationTarget = identical(key, guidedTourHomeNavKey) ||
        identical(key, guidedTourMaterialsKey) ||
        identical(key, guidedTourMediaKey) ||
        identical(key, guidedTourMoreKey);
    // The navigation label is the stable anchor, while the spotlight expands
    // to cover the full, comfortable destination tap area around it.
    setState(() => _targetRect = rect.inflate(isNavigationTarget ? 22.0 : 7.0));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final step = guidedTourSteps[widget.stepIndex];
    final target = _targetRect;
    final tooltipWidth = (size.width - 32).clamp(260.0, 360.0).toDouble();
    final showBelow = target == null || target.center.dy < size.height * .56;
    final tooltipTop = target == null
        ? size.height * .34
        : showBelow
            ? (target.bottom + 18).clamp(16.0, size.height - 220).toDouble()
            : (target.top - 190).clamp(16.0, size.height - 220).toDouble();
    final tooltipLeft = (size.width - tooltipWidth) / 2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _SpotlightPainter(
              target: target,
              scrim: Colors.black.withValues(alpha: .72),
              accent: colors.primary,
            ),
          ),
          if (target != null)
            Positioned.fromRect(
              rect: target,
              child: Semantics(
                button: true,
                label: l10n.t(step.titleKey),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTargetTap,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          Positioned(
            left: tooltipLeft,
            top: tooltipTop,
            width: tooltipWidth,
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.primary.withValues(alpha: .55)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: .24), blurRadius: 28, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.t(step.titleKey),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${widget.stepIndex + 1}/${guidedTourSteps.length}',
                          style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(l10n.t(step.descriptionKey), style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.touch_app_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 7),
                        Expanded(child: Text(l10n.t(step.hintKey), style: theme.textTheme.labelMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w700))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: widget.onSkip,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: Text(l10n.t('guidedTourSkip')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.target, required this.scrim, required this.accent});

  final Rect? target;
  final Color scrim;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final rect = target;
    if (rect == null) {
      canvas.drawPath(full, Paint()..color = scrim);
      return;
    }
    final hole = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(17)));
    canvas.drawPath(Path.combine(PathOperation.difference, full, hole), Paint()..color = scrim);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(17)),
      Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.scrim != scrim || oldDelegate.accent != accent;
}

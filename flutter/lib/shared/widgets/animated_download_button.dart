import 'dart:async';

import 'package:flutter/material.dart';

enum DownloadActionPhase {
  idle,
  downloading,
  success,
  view,
  failed,
}

/// A compact download action that morphs into a local-view action after saving.
/// Progress is optional because some servers do not send Content-Length.
class AnimatedDownloadButton extends StatefulWidget {
  const AnimatedDownloadButton({
    super.key,
    required this.phase,
    required this.progress,
    required this.downloadLabel,
    required this.viewLabel,
    required this.successLabel,
    required this.retryLabel,
    required this.tooltip,
    required this.onDownload,
    required this.onView,
    required this.onSuccessAnimationComplete,
  });

  final DownloadActionPhase phase;
  final double? progress;
  final String downloadLabel;
  final String viewLabel;
  final String successLabel;
  final String retryLabel;
  final String tooltip;
  final VoidCallback onDownload;
  final VoidCallback onView;
  final VoidCallback onSuccessAnimationComplete;

  @override
  State<AnimatedDownloadButton> createState() => _AnimatedDownloadButtonState();
}

class _AnimatedDownloadButtonState extends State<AnimatedDownloadButton> {
  Timer? _successTimer;
  bool _reduceMotion = false;
  bool _initialPhaseChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!_initialPhaseChecked) {
      _initialPhaseChecked = true;
      _scheduleSuccessMorphIfNeeded();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _successTimer?.cancel();
      _scheduleSuccessMorphIfNeeded();
    }
  }

  void _scheduleSuccessMorphIfNeeded() {
    if (widget.phase != DownloadActionPhase.success) return;
    _successTimer = Timer(Duration(milliseconds: _reduceMotion ? 0 : 920), () {
      if (mounted && widget.phase == DownloadActionPhase.success) {
        widget.onSuccessAnimationComplete();
      }
    });
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final animationDuration = reduceMotion ? Duration.zero : const Duration(milliseconds: 390);
    final switchDuration = reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final phase = widget.phase;
    final isCompact = phase == DownloadActionPhase.idle;
    final width = isCompact ? 42.0 : 96.0;
    final isBusy = phase == DownloadActionPhase.downloading;
    final isSuccess = phase == DownloadActionPhase.success;
    final isView = phase == DownloadActionPhase.view;
    final isFailed = phase == DownloadActionPhase.failed;

    final background = switch (phase) {
      DownloadActionPhase.idle => colors.surfaceContainerHighest,
      DownloadActionPhase.downloading => colors.primaryContainer,
      DownloadActionPhase.success => colors.tertiaryContainer,
      DownloadActionPhase.view => colors.primaryContainer,
      DownloadActionPhase.failed => colors.errorContainer,
    };
    final foreground = switch (phase) {
      DownloadActionPhase.idle => colors.primary,
      DownloadActionPhase.downloading => colors.onPrimaryContainer,
      DownloadActionPhase.success => colors.onTertiaryContainer,
      DownloadActionPhase.view => colors.onPrimaryContainer,
      DownloadActionPhase.failed => colors.onErrorContainer,
    };
    final label = switch (phase) {
      DownloadActionPhase.idle => '',
      DownloadActionPhase.downloading => widget.progress == null
          ? '…'
          : '${(widget.progress!.clamp(0.0, 1.0).toDouble() * 100).round()}%',
      DownloadActionPhase.success => widget.successLabel,
      DownloadActionPhase.view => widget.viewLabel,
      DownloadActionPhase.failed => widget.retryLabel,
    };
    final icon = switch (phase) {
      DownloadActionPhase.idle => Icons.download_rounded,
      DownloadActionPhase.downloading => null,
      DownloadActionPhase.success => Icons.check_rounded,
      DownloadActionPhase.view => Icons.visibility_rounded,
      DownloadActionPhase.failed => Icons.refresh_rounded,
    };

    return Semantics(
      button: true,
      enabled: !isBusy && !isSuccess,
      label: isBusy
          ? '${widget.downloadLabel} $label'
          : isView
              ? widget.viewLabel
              : isSuccess
                  ? widget.successLabel
                  : isFailed
                      ? widget.retryLabel
                      : widget.downloadLabel,
      child: Tooltip(
        message: isView
            ? widget.viewLabel
            : isCompact
                ? widget.downloadLabel
                : isBusy
                    ? '${widget.downloadLabel} $label'
                    : isSuccess
                        ? widget.successLabel
                        : widget.retryLabel,
        child: AnimatedContainer(
          duration: animationDuration,
          curve: Curves.easeInOutCubic,
          width: width,
          height: 38,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: phase == DownloadActionPhase.idle
                  ? colors.outlineVariant
                  : background,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: isBusy || isSuccess
                  ? null
                  : isView
                      ? widget.onView
                      : widget.onDownload,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isBusy && widget.progress != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AnimatedContainer(
                          duration: animationDuration,
                          curve: Curves.linear,
                          width: width * widget.progress!.clamp(0.0, 1.0).toDouble(),
                          height: 38,
                          color: colors.primary.withValues(alpha: 0.22),
                        ),
                      ),
                    Center(
                      child: AnimatedSwitcher(
                        duration: switchDuration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: animation, child: child),
                        ),
                        child: isBusy
                            ? Row(
                                key: const ValueKey('progress'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: widget.progress,
                                      color: foreground,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: foreground,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              )
                            : isCompact
                                ? Icon(icon, key: const ValueKey('download-icon'), size: 20, color: foreground)
                                : Row(
                                    key: ValueKey('content-$phase'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, size: 17, color: foreground),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: foreground,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
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

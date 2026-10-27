import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/offline_state.dart';

/// Keeps connectivity visible without reserving a full-width banner row.
/// The indicator is intentionally compact and does not affect page layout.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineState.instance.isOffline,
      builder: (context, offline, _) {
        final l10n = AppLocalizations.of(context);
        final colors = Theme.of(context).colorScheme;
        final label = l10n.t(offline ? 'offline' : 'connected');
        final iconColor = offline ? colors.error : colors.primary;

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            PositionedDirectional(
              start: 10,
              bottom: MediaQuery.paddingOf(context).bottom + 76,
              child: Semantics(
                label: label,
                liveRegion: true,
                child: Tooltip(
                  message: label,
                  child: Material(
                    color: colors.surface.withValues(alpha: 0.94),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                        tooltip: label,
                        onPressed: () => _showConnectionStatus(context, label),
                        icon: Icon(
                          offline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                          size: 17,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showConnectionStatus(BuildContext context, String label) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(label),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

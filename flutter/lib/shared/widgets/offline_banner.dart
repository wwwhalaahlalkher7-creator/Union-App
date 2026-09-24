import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/offline_state.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineState.instance.isOffline,
      builder: (context, offline, _) {
        if (!offline) return child;
        final cs = Theme.of(context).colorScheme;
        final banner = SafeArea(
          bottom: false,
          child: Material(
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 17, color: cs.onSurfaceVariant),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).t('offline'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return Column(
          children: [
            banner,
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

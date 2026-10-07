part of 'materials_screen.dart';

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.progressFuture,
    required this.onTap,
  });

  final MaterialItem material;
  final Future<ProgressSnapshot>? progressFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<ProgressSnapshot>(
      future: progressFuture,
      builder: (context, snapshot) {
        MaterialProgress? progress;
        for (final item in snapshot.data?.items ?? const <MaterialProgress>[]) {
          if (item.materialId == material.id) {
            progress = item;
            break;
          }
        }
        final percent = (progress?.percent ?? 0).clamp(0, 100).toInt();
        final completed = progress?.completed == true || percent >= 100;

        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            material.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w700),
                          ),
                          if (material.size != null && material.size! > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatFileSize(material.size!),
                              textAlign: TextAlign.start,
                              style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: percent / 100),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: percent.toDouble()),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        completed ? l10n.t('completed') : '${l10n.t('progress')}: ${value.round()}%',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: completed ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) return '';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final decimals = index == 0 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(decimals)} ${units[index]}';
}


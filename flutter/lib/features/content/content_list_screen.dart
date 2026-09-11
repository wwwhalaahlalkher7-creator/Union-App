import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';

class ContentListScreen extends StatefulWidget {
  const ContentListScreen({required this.titleKey, required this.loader, required this.icon, super.key});
  final String titleKey;
  final Future<List<ContentItem>> Function(ContentRepository) loader;
  final IconData icon;
  @override State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  late final ApiClient _client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
  late final ContentRepository _repository = ContentRepository(_client);
  late Future<List<ContentItem>> _future = widget.loader(_repository);

  @override void dispose() { _client.dispose(); super.dispose(); }
  void _retry() => setState(() => _future = widget.loader(_repository));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t(widget.titleKey)), actions: [
        IconButton(tooltip: l10n.t('refresh'), onPressed: _retry, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: FutureBuilder<List<ContentItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const _Loading();
          if (snapshot.hasError) return _StateMessage(icon: Icons.cloud_off_outlined, message: l10n.t('connectionFailed'), onRetry: _retry);
          final items = snapshot.data ?? const <ContentItem>[];
          if (items.isEmpty) return _StateMessage(icon: widget.icon, message: l10n.t('noData'));
          return RefreshIndicator(
            onRefresh: () async { _retry(); await _future; },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                AppSection(
                  title: l10n.t(widget.titleKey),
                  subtitle: 'محتوى منشور من الرابطة',
                  child: Column(children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(widget.icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.title.isEmpty ? l10n.t('noData') : item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                              if (item.summary?.isNotEmpty == true) ...[
                                const SizedBox(height: 6),
                                Text(item.summary!, maxLines: 5, overflow: TextOverflow.ellipsis),
                              ],
                            ])),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
}
class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.message, this.onRetry});
  final IconData icon; final String message; final VoidCallback? onRetry;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 60), const SizedBox(height: 14), Text(message, textAlign: TextAlign.center), if (onRetry != null) ...[const SizedBox(height: 14), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة'))]])));
}

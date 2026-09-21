import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_card.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final ApiClient _client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
  late final ContentRepository _repo = ContentRepository(_client);
  late Future<List<ContentItem>> _future = _repo.achievements();

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = _repo.achievements();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('achievements')),
        actions: [
          IconButton(
            tooltip: l10n.t('refresh'),
            onPressed: () => setState(() => _future = _repo.achievements()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<ContentItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : l10n.t('connectionFailed')));
          }
          final items = snapshot.data ?? const <ContentItem>[];
          if (items.isEmpty) return Center(child: Text(l10n.t('noData')));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 28),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final image = item.imageUrl?.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (image?.isNotEmpty == true)
                          AspectRatio(
                            aspectRatio: 16 / 8,
                            child: Image.network(image!, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox.shrink()),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (item.badge?.isNotEmpty == true)
                                Text(item.badge!, style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                )),
                              const SizedBox(height: 5),
                              Text(item.title, style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16,
                              )),
                              if (item.body?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(item.body!, style: const TextStyle(height: 1.6)),
                              ],
                              if (item.highlights.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  item.highlightsTitle?.isNotEmpty == true
                                      ? item.highlightsTitle!
                                      : 'أبرز المحاور',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                for (final point in item.highlights)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('•  '),
                                        Expanded(child: Text(point, style: const TextStyle(height: 1.45))),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

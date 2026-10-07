import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/error_message.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/list_skeleton.dart';
import 'media_card.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({this.initialTab = 0, super.key});
  final int initialTab;

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> with SingleTickerProviderStateMixin {
  late final ContentRepository _repo = AppDependencies.instance.content;
  late final TabController _tabs = TabController(
    length: 3,
    initialIndex: widget.initialTab.clamp(0, 2),
    vsync: this,
  );

  late int _index = widget.initialTab.clamp(0, 2);
  final Map<int, List<ContentItem>> _items = <int, List<ContentItem>>{};
  final Set<int> _loadingTabs = <int>{};
  final Set<int> _loadedTabs = <int>{};
  final Set<int> _failedTabs = <int>{};
  final Map<int, String> _errors = <int, String>{};

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
    _loadTab(_index, forceRefresh: true);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || _index == _tabs.index) return;
    setState(() => _index = _tabs.index);
    _loadTab(_index);
  }

  Future<List<ContentItem>> _fetch(int index, {bool forceRefresh = false}) {
    return switch (index) {
      0 => _repo.news(forceRefresh: forceRefresh),
      1 => _repo.achievements(forceRefresh: forceRefresh),
      _ => _repo.events(forceRefresh: forceRefresh),
    };
  }

  Future<void> _loadTab(int index, {bool forceRefresh = false}) async {
    if (_loadingTabs.contains(index)) return;
    if (!forceRefresh && _loadedTabs.contains(index)) return;

    if (mounted) {
      setState(() {
        _loadingTabs.add(index);
        _failedTabs.remove(index);
        _errors.remove(index);
      });
    }
    try {
      final items = await _fetch(index, forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _items[index] = items;
        _loadedTabs.add(index);
        _failedTabs.remove(index);
        _errors.remove(index);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failedTabs.add(index);
        _errors[index] = ErrorMessage.from(context, error, fallbackKey: 'connectionFailed');
      });
    } finally {
      if (mounted) setState(() => _loadingTabs.remove(index));
    }
  }

  Future<void> _refresh() async {
    await _loadTab(_index, forceRefresh: true);
  }

  Future<void> _openDetail(ContentItem item) async {
    await context.push(
      '/media/detail?type=${Uri.encodeQueryComponent(_type())}&id=${Uri.encodeQueryComponent(item.id)}',
    );
  }

  String _type() => switch (_index) {
    0 => 'news',
    1 => 'achievement',
    _ => 'event',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.t('news'), l10n.t('achievements'), l10n.t('events')];
    final icons = [Icons.article_outlined, Icons.emoji_events_outlined, Icons.event_outlined];
    final loading = _loadingTabs.contains(_index);
    final failed = _failedTabs.contains(_index);
    final items = _items[_index] ?? const <ContentItem>[];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 96),
        children: [
          Text(
            l10n.t('media'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.t('mediaSubtitle'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(15),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              tabs: [
                for (var i = 0; i < 3; i++)
                  Tab(icon: Icon(icons[i], size: 17), text: labels[i]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: loading && items.isEmpty
                ? ListSkeleton(key: ValueKey('skeleton-$_index'), count: 3)
                : failed && items.isEmpty
                    ? MediaState(
                        key: ValueKey('error-$_index'),
                        icon: Icons.cloud_off_outlined,
                        message: _errors[_index] ?? l10n.t('connectionFailed'),
                        retry: () => _loadTab(_index, forceRefresh: true),
                      )
                    : items.isEmpty
                        ? MediaState(
                            key: ValueKey('empty-$_index'),
                            icon: icons[_index],
                            message: l10n.t('noData'),
                            compact: true,
                          )
                        : Column(
                            key: ValueKey('content-$_index'),
                            children: [
                              if (loading)
                                const LinearProgressIndicator(minHeight: 2),
                              for (final item in items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 11),
                                  child: MediaCard(
                                    item: item,
                                    type: _type(),
                                    label: labels[_index],
                                    onDetails: () => _openDetail(item),
                                  ),
                                ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

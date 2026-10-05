import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/list_skeleton.dart';
import '../../shared/widgets/action_feedback.dart';
import 'content_detail_screen.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({this.initialTab = 0, super.key});
  final int initialTab;

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> with SingleTickerProviderStateMixin {
  late final ContentRepository _repo = ContentRepository();
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
      });
    }
    try {
      final items = await _fetch(index, forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _items[index] = items;
        _loadedTabs.add(index);
        _failedTabs.remove(index);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failedTabs.add(index));
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
                    ? _MediaState(
                        key: ValueKey('error-$_index'),
                        icon: Icons.cloud_off_outlined,
                        message: l10n.t('connectionFailed'),
                        retry: () => _loadTab(_index, forceRefresh: true),
                      )
                    : items.isEmpty
                        ? _MediaState(
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
                                  child: _MediaCard(
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

class _MediaCard extends StatefulWidget {
  const _MediaCard({required this.item, required this.type, required this.label, required this.onDetails, super.key});
  final ContentItem item; final String type; final String label; final VoidCallback onDetails;
  @override State<_MediaCard> createState() => _MediaCardState();
}
class _MediaCardState extends State<_MediaCard> {
  late bool _liked = widget.item.myReaction == 'like';
  late int _likeCount = widget.item.likeCount;
  late int _commentCount = widget.item.commentCount;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id || oldWidget.item.likeCount != widget.item.likeCount || oldWidget.item.myReaction != widget.item.myReaction) {
      _liked = widget.item.myReaction == 'like';
      _likeCount = widget.item.likeCount;
      _commentCount = widget.item.commentCount;
    }
  }

  Future<void> _like() async {
    if (_busy) return;
    setState(() => _busy = true);
    ApiClient? client;
    try {
      client = await AuthenticatedClient.create();
      final repo = InteractionsRepository(client);
      if (_liked) {
        await repo.unreact(widget.type, widget.item.id);
        if (mounted) {
          setState(() { _liked = false; _likeCount = _likeCount > 0 ? _likeCount - 1 : 0; });
          ActionFeedback.show(context, type: ActionFeedbackType.unlike);
        }
      } else {
        await repo.react(widget.type, widget.item.id, 'like');
        if (mounted) {
          setState(() { _liked = true; _likeCount += 1; });
          ActionFeedback.show(context, type: ActionFeedbackType.like);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : AppLocalizations.of(context).t('likeFailed'))));
    } finally {
      client?.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final image = widget.item.images.isNotEmpty ? widget.item.images.first : widget.item.imageUrl;
    return AppCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(children: [
        _MediaImage(url: image, label: widget.label, icon: widget.type == 'news' ? Icons.article_rounded : (widget.type == 'achievement' ? Icons.emoji_events_rounded : Icons.event_available_rounded)),
        PositionedDirectional(top: 10, start: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Text((widget.type == 'achievement' && widget.item.badge?.trim().isNotEmpty == true) ? widget.item.badge! : (widget.item.category?.trim().isNotEmpty == true ? widget.item.category! : widget.label), style: TextStyle(color: cs.onPrimaryContainer, fontSize: 9, fontWeight: FontWeight.w800)))),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(13, 11, 13, 9), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          onTap: widget.onDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, height: 1.35)),
              if (widget.item.summary?.trim().isNotEmpty == true || widget.item.body?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(widget.item.summary?.trim().isNotEmpty == true ? widget.item.summary! : widget.item.body!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.6, color: cs.onSurfaceVariant)),
              ],
              if (widget.type == 'event' && (widget.item.location?.trim().isNotEmpty == true || widget.item.eventAt != null || widget.item.endAt != null)) ...[
                const SizedBox(height: 7),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    if (widget.item.eventAt != null) _Meta(icon: Icons.schedule_rounded, text: '${AppLocalizations.of(context).t('eventStart')}: ${_date(widget.item.eventAt)}'),
                    _Meta(icon: Icons.event_available_rounded, text: '${AppLocalizations.of(context).t('eventEnd')}: ${widget.item.endAt != null ? _date(widget.item.endAt) : AppLocalizations.of(context).t('eventEndNotSet')}'),
                    if (widget.item.location?.trim().isNotEmpty == true) _Meta(icon: Icons.location_on_outlined, text: widget.item.location!),
                  ],
                ),
              ],
              if (widget.type == 'achievement' && widget.item.publisher?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 6),
                _Meta(icon: Icons.workspace_premium_outlined, text: widget.item.publisher!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 9),
        Row(children: [if (widget.type != 'event') Text(_date(widget.item.eventAt ?? widget.item.createdAt), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)), if (widget.type == 'event') const SizedBox.shrink(), const Spacer(), IconButton(visualDensity: VisualDensity.compact, onPressed: _busy ? null : _like, icon: Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 18, color: _liked ? cs.primary : cs.onSurfaceVariant)), Text('$_likeCount', style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)), const SizedBox(width: 4), IconButton(visualDensity: VisualDensity.compact, onPressed: () => _openComments(context), icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: cs.onSurfaceVariant)), Text('$_commentCount', style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant))])
      ]))
    ]));
  }
  void _openComments(BuildContext context) async {
    await showModalBottomSheet<void>(context: context, useSafeArea: true, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => ContentCommentsSheet(item: widget.item, type: widget.type, onCommentCountChanged: (count) { if (mounted) setState(() => _commentCount = count); }));
  }

}
String _date(DateTime? d) => d == null ? '' : '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
class _MediaImage extends StatelessWidget {
  const _MediaImage({this.url, required this.label, required this.icon});
  final String? url;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(320.0, 900.0);
    if (url?.trim().isNotEmpty == true) {
      return AspectRatio(
        aspectRatio: 16 / 7,
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => _fallback(context),
        ),
      );
    }
    return AspectRatio(aspectRatio: 16 / 7, child: _fallback(context));
  }

  Widget _fallback(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      );
}

class _MediaState extends StatelessWidget { const _MediaState({required this.icon,required this.message,this.retry,this.compact=false, super.key}); final IconData icon;final String message;final VoidCallback? retry;final bool compact;@override Widget build(BuildContext context)=>Center(child:Padding(padding:EdgeInsets.all(compact?26:40),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:48,color:Theme.of(context).colorScheme.onSurfaceVariant),const SizedBox(height:10),Text(message,textAlign:TextAlign.center,style:const TextStyle(fontSize:12)),if(retry!=null)...[const SizedBox(height:12),FilledButton.icon(onPressed:retry,icon:const Icon(Icons.refresh_rounded,size:17),label:Text(AppLocalizations.of(context).t('retry')))]])));
}

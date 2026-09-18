import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../shared/widgets/app_card.dart';
import 'content_detail_screen.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});
  @override State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> with SingleTickerProviderStateMixin {
  late final ApiClient _client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
  late final ContentRepository _repo = ContentRepository(_client);
  late final TabController _tabs = TabController(length: 3, vsync: this);
  int _index = 0;
  Future<List<ContentItem>>? _future;
  
  @override void initState() { super.initState(); _future = _repo.news(); _tabs.addListener(() { if (!_tabs.indexIsChanging) { setState(() => _index = _tabs.index); _load(); }}); }
  @override void dispose() { _tabs.dispose(); _client.dispose(); super.dispose(); }

  Future<List<ContentItem>> _fetch() => _index == 0 ? _repo.news() : (_index == 1 ? _repo.events() : _repo.activities());
  void _load() => setState(() => _future = _fetch());
  Future<void> _refresh() async { final f = _fetch(); setState(() => _future = f); await f; }
  String _type() => _index == 0 ? 'news' : (_index == 1 ? 'event' : 'activity');

  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.t('news'), l10n.t('events'), l10n.t('activities')];
    final icons = [Icons.article_outlined, Icons.event_outlined, Icons.directions_run_outlined];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<ContentItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _MediaState(icon: Icons.cloud_off_outlined, message: snapshot.error is ApiException ? (snapshot.error as ApiException).message : l10n.t('connectionFailed'), retry: _load);
          final items = snapshot.data ?? const <ContentItem>[];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 92),
            children: [
              Text(l10n.t('media'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(l10n.t('mediaSubtitle'), style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Container(
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(15)),
                child: TabBar(
                  controller: _tabs,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                  labelColor: Theme.of(context).colorScheme.onPrimary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  tabs: [for (var i = 0; i < 3; i++) Tab(icon: Icon(icons[i], size: 17), text: labels[i])],
                ),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty) _MediaState(icon: icons[_index], message: l10n.t('noData'), compact: true)
              else for (final item in items) Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _MediaCard(item: item, type: _type(), label: labels[_index], onDetails: () => context.push('/media/detail', extra: {'item': item, 'type': _type()})),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaCard extends StatefulWidget {
  const _MediaCard({required this.item, required this.type, required this.label, required this.onDetails});
  final ContentItem item; final String type; final String label; final VoidCallback onDetails;
  @override State<_MediaCard> createState() => _MediaCardState();
}
class _MediaCardState extends State<_MediaCard> {
  bool _liked = false, _busy = false;
  Future<void> _like() async {
    if (_busy) return;
    setState(() => _busy = true);
    ApiClient? client;
    try {
      client = await AuthenticatedClient.create();
      await InteractionsRepository(client).react(widget.type, widget.item.id, 'like');
      if (mounted) setState(() => _liked = true);
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
        _MediaImage(url: image, label: widget.label, icon: widget.type == 'news' ? Icons.article_rounded : (widget.type == 'event' ? Icons.event_available_rounded : Icons.directions_run_rounded)),
        PositionedDirectional(top: 10, start: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)), child: Text(widget.item.category?.trim().isNotEmpty == true ? widget.item.category! : widget.label, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 9, fontWeight: FontWeight.w800)))),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(13, 11, 13, 9), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 0),
        GestureDetector(onTap: widget.onDetails, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(widget.item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, height: 1.35)), if (widget.item.body?.trim().isNotEmpty == true) ...[const SizedBox(height: 5), Text(widget.item.body!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.6, color: cs.onSurfaceVariant))]])),
        const SizedBox(height: 9),
        Row(children: [Text(_date(widget.item.eventAt ?? widget.item.createdAt), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)), const Spacer(), IconButton(visualDensity: VisualDensity.compact, onPressed: _busy ? null : _like, icon: Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 18, color: _liked ? cs.primary : cs.onSurfaceVariant)), Text('${widget.item.likeCount + (_liked ? 1 : 0)}', style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)), const SizedBox(width: 4), IconButton(visualDensity: VisualDensity.compact, onPressed: () => _openComments(context), icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: cs.onSurfaceVariant)), Text('${widget.item.commentCount}', style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant))])
      ]))
    ]));
  }
  void _openComments(BuildContext context) => showModalBottomSheet<void>(context: context, useSafeArea: true, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => ContentCommentsSheet(item: widget.item, type: widget.type));
}
String _date(DateTime? d) => d == null ? '' : '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
class _MediaImage extends StatelessWidget { const _MediaImage({this.url, required this.label, required this.icon}); final String? url; final String label; final IconData icon; @override Widget build(BuildContext context) { if(url?.trim().isNotEmpty==true) return AspectRatio(aspectRatio:16/7,child:Image.network(url!,fit:BoxFit.cover,errorBuilder:(_,_,_)=>_fallback(context))); return AspectRatio(aspectRatio:16/7,child:_fallback(context)); } Widget _fallback(BuildContext context)=>Container(color:Theme.of(context).colorScheme.surfaceContainerHigh,child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:34,color:Theme.of(context).colorScheme.primary),const SizedBox(height:6),Text(label,style:TextStyle(fontSize:13,fontWeight:FontWeight.w900,color:Theme.of(context).colorScheme.primary))]))); }
class _MediaState extends StatelessWidget { const _MediaState({required this.icon,required this.message,this.retry,this.compact=false}); final IconData icon;final String message;final VoidCallback? retry;final bool compact;@override Widget build(BuildContext context)=>Center(child:Padding(padding:EdgeInsets.all(compact?26:40),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:48,color:Theme.of(context).colorScheme.onSurfaceVariant),const SizedBox(height:10),Text(message,textAlign:TextAlign.center,style:const TextStyle(fontSize:12)),if(retry!=null)...[const SizedBox(height:12),FilledButton.icon(onPressed:retry,icon:const Icon(Icons.refresh_rounded,size:17),label:Text(AppLocalizations.of(context).t('retry')))]])));
}

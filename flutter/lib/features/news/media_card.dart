import 'package:flutter/material.dart';

import '../../core/errors/error_message.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/widgets/action_feedback.dart';
import '../../shared/widgets/app_card.dart';
import 'content_detail_screen.dart';

class MediaCard extends StatefulWidget {
  const MediaCard({required this.item, required this.type, required this.label, required this.onDetails});
  final ContentItem item; final String type; final String label; final VoidCallback onDetails;
  @override State<MediaCard> createState() => _MediaCardState();
}
class _MediaCardState extends State<MediaCard> {
  late bool _liked = widget.item.myReaction == 'like';
  late int _likeCount = widget.item.likeCount;
  late int _commentCount = widget.item.commentCount;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant MediaCard oldWidget) {
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
    try {
      final repo = AppDependencies.instance.interactions;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'likeFailed'))));
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

class MediaState extends StatelessWidget { const MediaState({required this.icon,required this.message,this.retry,this.compact=false, super.key}); final IconData icon;final String message;final VoidCallback? retry;final bool compact;@override Widget build(BuildContext context)=>Center(child:Padding(padding:EdgeInsets.all(compact?26:40),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:48,color:Theme.of(context).colorScheme.onSurfaceVariant),const SizedBox(height:10),Text(message,textAlign:TextAlign.center,style:const TextStyle(fontSize:12)),if(retry!=null)...[const SizedBox(height:12),FilledButton.icon(onPressed:retry,icon:const Icon(Icons.refresh_rounded,size:17),label:Text(AppLocalizations.of(context).t('retry')))]])));
}

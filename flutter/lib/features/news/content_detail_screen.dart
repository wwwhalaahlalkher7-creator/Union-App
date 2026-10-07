import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../data/models/comment_item.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/content_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../shared/widgets/action_feedback.dart';

part 'content_detail_widgets.dart';
part 'content_comments_sheet.dart';

class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({required this.id, required this.type, super.key});
  final String id;
  final String type;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  ContentItem? _fresh;
  bool _loading = true;
  String? _error;
  bool _liked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final item = await AppDependencies.instance.content.detail(widget.type, widget.id);
      if (!mounted) return;
      setState(() {
        _fresh = item;
        _liked = item.myReaction == 'like';
        _likeCount = item.likeCount;
        _commentCount = item.commentCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMessage.from(context, e, fallbackKey: 'connectionFailed');
      });
    }
  }

  Future<void> _like() async {
    if (_busy) return;
    final current = _fresh;
    if (current == null) return;
    setState(() => _busy = true);
    try {
      final repo = AppDependencies.instance.interactions;
      if (_liked) {
        await repo.unreact(widget.type, current.id);
        if (mounted) {
          setState(() { _liked = false; _likeCount = _likeCount > 0 ? _likeCount - 1 : 0; });
          ActionFeedback.show(context, type: ActionFeedbackType.unlike);
        }
      } else {
        await repo.react(widget.type, current.id, 'like');
        if (mounted) {
          setState(() { _liked = true; _likeCount += 1; });
          ActionFeedback.show(context, type: ActionFeedbackType.like);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessage.from(context, e, fallbackKey: 'likeFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final item = _fresh;
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.type == 'news' ? l10n.t('news') : widget.type == 'achievement' ? l10n.t('achievements') : l10n.t('events'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(_error ?? l10n.t('connectionFailed'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _loadDetail, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.t('retry'))),
            ]),
          ),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final images = item.images.isNotEmpty
        ? item.images
        : (item.imageUrl?.trim().isNotEmpty == true ? [item.imageUrl!] : const <String>[]);
    final label = widget.type == 'news'
        ? l10n.t('news')
        : widget.type == 'achievement'
            ? l10n.t('achievements')
            : l10n.t('events');

    final mediaTab = widget.type == 'achievement' ? 1 : widget.type == 'event' ? 2 : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.type == 'achievement' && item.badge?.trim().isNotEmpty == true
              ? item.badge!
              : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: () {
            // Return to the already-open MediaScreen instead of replacing it.
            // This preserves the exact tab (news/achievements/events) the
            // student came from. The fallback keeps direct/deep links safe.
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/media?tab=$mediaTab');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 28),
        children: [
          if (images.isNotEmpty)
            _Gallery(images: images)
          else
            _Fallback(label: label, icon: widget.type == 'news' ? Icons.article_rounded : widget.type == 'achievement' ? Icons.emoji_events_rounded : Icons.event_available_rounded),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.35)),
                const SizedBox(height: 7),
                if (widget.type == 'event') ...[
                  if (item.eventAt != null) Text('${l10n.t('eventStart')}: ${_date(item.eventAt)}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('${l10n.t('eventEnd')}: ${item.endAt != null ? _date(item.endAt) : l10n.t('eventEndNotSet')}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ] else
                  Text(_date(item.eventAt ?? item.createdAt), style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
                if (item.location?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(item.location!, style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
                ],
                if (item.body?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(item.body!, style: const TextStyle(fontSize: 13, height: 1.75)),
                ],
                if (widget.type == 'achievement' && item.highlights.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(item.highlightsTitle?.trim().isNotEmpty == true ? item.highlightsTitle! : l10n.t('highlights'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ...item.highlights.map((highlight) => Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 7),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.check_circle_rounded, size: 17, color: cs.primary),
                      const SizedBox(width: 7),
                      Expanded(child: Text(highlight, style: const TextStyle(fontSize: 12, height: 1.55))),
                    ]),
                  )),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _like,
                      icon: Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 16),
                      label: Text('${_liked ? l10n.t('liked') : l10n.t('like')} $_likeCount'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openComments(context, item),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: Text('${l10n.t('comments')} $_commentCount'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openComments(BuildContext context, ContentItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContentCommentsSheet(item: item, type: widget.type, onCommentCountChanged: (count) {
        if (mounted) setState(() => _commentCount = count);
      }),
    );
  }
}


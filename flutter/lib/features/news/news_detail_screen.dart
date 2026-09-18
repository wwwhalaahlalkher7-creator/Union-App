import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/comment_item.dart';
import '../../data/models/content_item.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../shared/widgets/app_card.dart';

class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({required this.item, super.key});
  final ContentItem item;
  @override State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  ApiClient? _client;
  Future<List<CommentItem>>? _comments;
  final _comment = TextEditingController();
  bool _sending = false;
  bool _liked = false;
  bool _reacting = false;

  @override void initState() { super.initState(); _loadComments(); }

  Future<void> _loadComments() async {
    final future = _fetchComments();
    setState(() => _comments = future);
    await future;
  }

  Future<List<CommentItem>> _fetchComments() async {
    final client = ApiClient(baseUrl: AppConstants.apiBaseUrl);
    try {
      return await InteractionsRepository(client).comments('news', widget.item.id);
    } finally {
      client.dispose();
    }
  }

  Future<void> _toggleLike() async {
    setState(() => _reacting = true);
    try {
      _client ??= await AuthenticatedClient.create();
      await InteractionsRepository(_client!).react('news', widget.item.id, 'like');
      if (mounted) setState(() => _liked = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر تسجيل الإعجاب')));
    } finally {
      if (mounted) setState(() => _reacting = false);
    }
  }

  Future<void> _addComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      _client ??= await AuthenticatedClient.create();
      await InteractionsRepository(_client!).addComment('news', widget.item.id, text);
      _comment.clear();
      await _loadComments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر التعليق')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر نشر التعليق')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override void dispose() { _comment.dispose(); _client?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الخبر')),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(14.72, 10, 14.72, 28),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(item.category ?? 'خبر', style: TextStyle(color: cs.primary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(item.title, textAlign: TextAlign.end, style: const TextStyle(fontSize: 19.3, fontWeight: FontWeight.w900, height: 1.35)),
                const SizedBox(height: 9),
                if (item.publisher?.isNotEmpty == true) Text(item.publisher!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5)),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: OutlinedButton.icon(
                    onPressed: _reacting ? null : _toggleLike,
                    icon: Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, size: 16),
                    label: Text(_liked ? 'تم الإعجاب' : 'إعجاب'),
                  ),
                ),
                if (item.body?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(item.body!, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, height: 1.7)),
                ] else if (item.summary?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(item.summary!, textAlign: TextAlign.end, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.7)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                Row(children: [Expanded(child: Text('التعليقات', textAlign: TextAlign.end, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))), Icon(Icons.chat_bubble_outline_rounded, color: cs.primary)]),
                const SizedBox(height: 10),
                TextField(controller: _comment, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب تعليقك')),
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton.icon(onPressed: _sending ? null : _addComment, icon: const Icon(Icons.send_rounded, size: 16), label: Text(_sending ? '...' : 'نشر'))),
                const SizedBox(height: 8),
                FutureBuilder<List<CommentItem>>(
                  future: _comments,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator());
                    if (snapshot.hasError) return Text(AppLocalizations.of(context).t('connectionFailed'));
                    final list = snapshot.data ?? const <CommentItem>[];
                    if (list.isEmpty) return const Text('لا توجد تعليقات بعد.', textAlign: TextAlign.center);
                    return Column(children: [for (final comment in list) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(comment.body, textAlign: TextAlign.end, style: const TextStyle(fontSize: 11.5)), subtitle: Text(comment.studentName, textAlign: TextAlign.end, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))]);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

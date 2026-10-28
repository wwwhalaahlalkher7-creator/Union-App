import 'package:flutter/material.dart';

import '../../api_service.dart';

class FeedbackReportsPage extends StatefulWidget {
  const FeedbackReportsPage({super.key, required this.api});
  final ApiService api;

  @override
  State<FeedbackReportsPage> createState() => _FeedbackReportsPageState();
}

class _FeedbackReportsPageState extends State<FeedbackReportsPage> {
  String _status = 'visible';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _comments = [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
      : <Map<String, dynamic>>[];

  String _statusLabel(String value) => switch (value) {
        'visible' => 'ظاهر',
        'hidden' => 'مخفي',
        'deleted' => 'محذوف',
        _ => value,
      };

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.get('/admin/moderation/comments?status=$_status&limit=100');
      if (mounted) setState(() => _comments = _rows(result['data'] ?? result));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(Map<String, dynamic> comment, String status) async {
    final id = comment['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _busy.add(id));
    try {
      await widget.api.patch('/admin/moderation/comments/$id', body: {'status': status});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديث حالة التعليق إلى «${_statusLabel(status)}».')));
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث التعليق: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _review(Map<String, dynamic> comment) async {
    final current = comment['status']?.toString() ?? _status;
    final selected = ValueNotifier<String>(current);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مراجعة التعليق'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('الطالب: ${comment['full_name'] ?? 'غير معروف'}'),
              Text('الرقم الجامعي: ${comment['student_number'] ?? '—'}'),
              Text('نوع المحتوى: ${comment['content_type'] ?? '—'}'),
              Text('معرّف المحتوى: ${comment['content_id'] ?? '—'}'),
              const SizedBox(height: 12),
              const Text('نص التعليق', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              SelectableText(comment['body']?.toString() ?? 'لا يوجد نص'),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                valueListenable: selected,
                builder: (context, value, _) => DropdownButtonFormField<String>(
                  value: value,
                  decoration: const InputDecoration(labelText: 'حالة الإشراف'),
                  items: const [
                    DropdownMenuItem(value: 'visible', child: Text('ظاهر')),
                    DropdownMenuItem(value: 'hidden', child: Text('إخفاء التعليق')),
                    DropdownMenuItem(value: 'deleted', child: Text('وضع علامة محذوف')),
                  ],
                  onChanged: (next) { if (next != null) selected.value = next; },
                ),
              ),
              const SizedBox(height: 8),
              const Text('يتم حفظ التغيير في الخادم ويُسجل في سجل التدقيق.'),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ الحالة')),
        ],
      ),
    );
    final next = selected.value;
    selected.dispose();
    if (accepted == true && next != current && mounted) await _setStatus(comment, next);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('إشراف التعليقات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text('إدارة ظهور تعليقات الطلاب باستخدام واجهات الإشراف المتاحة في الـBackend.'),
              ])),
              IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
            ]),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'visible', label: Text('ظاهرة')),
                ButtonSegment(value: 'hidden', label: Text('مخفية')),
                ButtonSegment(value: 'deleted', label: Text('محذوفة')),
              ],
              selected: {_status},
              onSelectionChanged: (selection) {
                setState(() { _status = selection.first; _comments = []; });
                _load();
              },
            ),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تعذر تحميل التعليقات: $_error'),
              Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))),
            ]))),
            if (!_loading && _error == null && _comments.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد تعليقات بهذه الحالة.'))),
            for (final comment in _comments)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(_status == 'visible' ? Icons.visibility_outlined : _status == 'hidden' ? Icons.visibility_off_outlined : Icons.delete_outline)),
                  title: Text('${comment['full_name'] ?? 'طالب غير معروف'} • ${comment['student_number'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text('${comment['body'] ?? 'لا يوجد نص'}\n${comment['content_type'] ?? '—'} • ${comment['created_at'] ?? ''}', maxLines: 4, overflow: TextOverflow.ellipsis)),
                  isThreeLine: true,
                  trailing: _busy.contains(comment['id']?.toString())
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : PopupMenuButton<String>(
                          onSelected: (value) => _setStatus(comment, value),
                          itemBuilder: (_) => [
                            if (_status != 'visible') const PopupMenuItem(value: 'visible', child: Text('إظهار التعليق')),
                            if (_status != 'hidden') const PopupMenuItem(value: 'hidden', child: Text('إخفاء التعليق')),
                            if (_status != 'deleted') const PopupMenuItem(value: 'deleted', child: Text('وضع علامة محذوف')),
                          ],
                        ),
                  onTap: () => _review(comment),
                ),
              ),
          ],
        ),
      );
}

import 'package:flutter/material.dart';
import '../../api_service.dart';

/// Unified moderation inbox for student feedback and public chat reports.
/// Each record keeps its original API/status contract; only presentation is shared.
class FeedbackReportsPage extends StatefulWidget {
  const FeedbackReportsPage({super.key, required this.api});
  final ApiService api;

  @override
  State<FeedbackReportsPage> createState() => _FeedbackReportsPageState();
}

class _FeedbackReportsPageState extends State<FeedbackReportsPage> {
  String _view = 'current'; // current, solved, archived
  String _type = 'all'; // all, suggestion, report, chat
  String _query = '';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _allItems = [];
  final Set<String> _busy = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await widget.api.get(
        '/admin/moderation/inbox?view=all&type=all&limit=500',
      );
      final rows = _rows(response['data']);
      final normalized = rows.map((item) => <String, dynamic>{
        ...item,
        '_source': item['source']?.toString() ?? 'feedback',
        '_status': item['status']?.toString() ?? 'open',
      }).toList()
        ..sort((a, b) => _dateValue(b['createdAt']).compareTo(_dateValue(a['createdAt'])));
      if (!mounted) return;
      setState(() {
        _allItems = normalized;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المقترحات والبلاغات وبلاغات الدردشة: $error';
        _allItems = [];
        _loading = false;
      });
    }
  }

  DateTime _dateValue(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _source(Map<String, dynamic> item) => item['_source']?.toString() ?? 'feedback';
  String _status(Map<String, dynamic> item) => item['_status']?.toString() ?? 'open';
  String _id(Map<String, dynamic> item) => item['id']?.toString() ?? '';
  String _busyKey(Map<String, dynamic> item) => '${_source(item)}:${_id(item)}';

  String _typeLabel(Map<String, dynamic> item) {
    if (_source(item) == 'chat') return 'بلاغ دردشة';
    final category = item['category']?.toString() ?? 'other';
    return category == 'suggestion' ? 'مقترح' : 'بلاغ عام';
  }

  String _title(Map<String, dynamic> item) {
    if (_source(item) == 'chat') {
      return 'بلاغ: ${item['reason'] ?? 'سبب غير محدد'}';
    }
    return item['title']?.toString().trim().isNotEmpty == true
        ? item['title'].toString()
        : 'بدون عنوان';
  }

  String _message(Map<String, dynamic> item) {
    if (_source(item) == 'chat') {
      return item['messageBody']?.toString() ?? 'محتوى الرسالة غير متاح';
    }
    return item['details']?.toString() ?? '';
  }

  String _statusLabel(Map<String, dynamic> item) {
    final status = _status(item);
    if (_source(item) == 'chat') {
      return switch (status) {
        'open' => 'مفتوح',
        'reviewed' => 'تمت المراجعة',
        'dismissed' => 'مرفوض',
        'archived' => 'مؤرشف',
        _ => status,
      };
    }
    return switch (status) {
      'open' => 'جديد',
      'in_review' => 'قيد المراجعة',
      'resolved' => 'تم الحل',
      'dismissed' => 'مرفوض',
      'archived' => 'مؤرشف',
      _ => status,
    };
  }

  bool _isSolved(Map<String, dynamic> item) =>
      _source(item) == 'chat' ? _status(item) == 'reviewed' : _status(item) == 'resolved';
  bool _isArchived(Map<String, dynamic> item) =>
      _status(item) == 'archived' || _status(item) == 'dismissed';

  List<Map<String, dynamic>> get _visibleItems {
    final query = _query.trim().toLowerCase();
    return _allItems.where((item) {
      final status = _status(item);
      final inView = switch (_view) {
        'solved' => _isSolved(item),
        'archived' => _isArchived(item),
        _ => status == 'open' || status == 'in_review',
      };
      if (!inView) return false;
      final type = _typeLabel(item);
      final matchesType = switch (_type) {
        'suggestion' => type == 'مقترح',
        'report' => type == 'بلاغ عام',
        'chat' => type == 'بلاغ دردشة',
        _ => true,
      };
      if (!matchesType) return false;
      if (query.isEmpty) return true;
      final searchable = [
        _title(item), _message(item), type,
        item['studentName'], item['studentNumber'], item['screen'],
        item['authorName'], item['reporterName'], item['reason'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  int _countWhere(bool Function(Map<String, dynamic>) predicate) =>
      _allItems.where(predicate).length;

  Future<void> _changeStatus(
    Map<String, dynamic> item, {
    required String status,
    String? messageStatus,
    String? adminNotes,
  }) async {
    final id = _id(item);
    if (id.isEmpty) return;
    final key = _busyKey(item);
    setState(() => _busy.add(key));
    try {
      if (_source(item) == 'chat') {
        await widget.api.patch('/admin/moderation/chat-reports/$id', body: {
          'status': status,
          if (messageStatus != null) 'messageStatus': messageStatus,
        });
      } else {
        await widget.api.patch('/admin/moderation/feedback/$id', body: {
          'status': status,
          if (adminNotes != null && adminNotes.trim().isNotEmpty)
            'adminNotes': adminNotes.trim(),
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث السجل بنجاح.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث السجل: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    var selectedStatus = _status(item);
    var messageStatus = (item['messageStatus']?.toString() == 'hidden') ? 'hidden' : 'visible';
    final notesController = TextEditingController(text: item['adminNotes']?.toString() ?? '');
    final source = _source(item);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_typeLabel(item) == 'بلاغ دردشة' ? 'تفاصيل بلاغ الدردشة' : 'تفاصيل المقترح أو البلاغ'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(label: Text(_typeLabel(item))),
                    Chip(label: Text(_statusLabel(item))),
                  ]),
                  const SizedBox(height: 10),
                  Text('العنوان', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  SelectableText(_title(item)),
                  const SizedBox(height: 14),
                  Text(source == 'chat' ? 'الرسالة المبلّغ عنها' : 'التفاصيل', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  SelectableText(_message(item)),
                  const SizedBox(height: 14),
                  if (source == 'chat') ...[
                    Text('صاحب الرسالة: ${item['authorName'] ?? 'غير معروف'}'),
                    Text('المبلّغ: ${item['reporterName'] ?? 'غير معروف'}'),
                    if ((item['details'] ?? '').toString().trim().isNotEmpty)
                      Text('تفاصيل إضافية: ${item['details']}'),
                  ] else ...[
                    Text('الطالب: ${item['studentName'] ?? 'غير معروف'}'),
                    Text('الرقم الجامعي: ${item['studentNumber'] ?? 'غير متاح'}'),
                    if ((item['screen'] ?? '').toString().trim().isNotEmpty)
                      Text('المصدر: ${item['screen']}'),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'ملاحظات الإدارة (اختيارية)'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text('تغيير الحالة', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    isExpanded: true,
                    items: (source == 'chat'
                            ? const [
                                DropdownMenuItem(value: 'open', child: Text('مفتوح')),
                                DropdownMenuItem(value: 'reviewed', child: Text('تمت المراجعة')),
                                DropdownMenuItem(value: 'dismissed', child: Text('مرفوض')),
                                DropdownMenuItem(value: 'archived', child: Text('أرشفة البلاغ')),
                              ]
                            : const [
                                DropdownMenuItem(value: 'open', child: Text('جديد')),
                                DropdownMenuItem(value: 'in_review', child: Text('قيد المراجعة')),
                                DropdownMenuItem(value: 'resolved', child: Text('تم الحل')),
                                DropdownMenuItem(value: 'dismissed', child: Text('مرفوض')),
                                DropdownMenuItem(value: 'archived', child: Text('أرشفة البلاغ')),
                              ]),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStatus = value);
                      }
                    },
                  ),
                  if (source == 'chat' && selectedStatus == 'reviewed') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: messageStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الإجراء على الرسالة'),
                      items: const [
                        DropdownMenuItem(value: 'visible', child: Text('الإبقاء على الرسالة ظاهرة')),
                        DropdownMenuItem(value: 'hidden', child: Text('إخفاء الرسالة')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => messageStatus = value);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إغلاق')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ التغييرات')),
          ],
        ),
      ),
    );
    final notes = notesController.text;
    notesController.dispose();
    if (result != true || !mounted) return;
    await _changeStatus(
      item,
      status: selectedStatus,
      messageStatus: source == 'chat' && selectedStatus == 'reviewed' ? messageStatus : null,
      adminNotes: source == 'feedback' ? notes : null,
    );
  }

  Color _statusColor(BuildContext context, Map<String, dynamic> item) {
    final scheme = Theme.of(context).colorScheme;
    return switch (_status(item)) {
      'resolved' || 'reviewed' => Colors.green.shade700,
      'in_review' => Colors.orange.shade800,
      'dismissed' => scheme.outline,
      _ => scheme.primary,
    };
  }

  Widget _viewCard({required String view, required String title, required String subtitle, required IconData icon, required int count, required Color color}) {
    final active = _view == view;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: active ? color.withValues(alpha: 0.10) : scheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _view = view),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: active ? color.withValues(alpha: 0.65) : scheme.outlineVariant),
              boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 5))] : null,
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text('$count سجل', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
              ])),
              Icon(Icons.arrow_back, color: active ? color : scheme.outline),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _recordActions(Map<String, dynamic> item) {
    final busy = _busy.contains(_busyKey(item));
    return IconButton(
      tooltip: 'عرض التفاصيل وتحديث الحالة',
      onPressed: busy ? null : () => _openDetails(item),
      icon: busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.visibility_outlined),
    );
  }

  Widget _desktopTable(List<Map<String, dynamic>> items) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) return const _EmptyRecords();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 760),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerHighest.withValues(alpha: 0.55)),
          columns: const [
            DataColumn(label: Text('النوع')),
            DataColumn(label: Text('القسم / المرسل')),
            DataColumn(label: Text('الرسالة')),
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('')),
          ],
          rows: items.map((item) {
            final message = _message(item).replaceAll('\n', ' ').trim();
            final shortMessage = message.length > 74 ? '${message.substring(0, 74)}…' : message;
            final sender = _source(item) == 'chat'
                ? (item['reporterName']?.toString() ?? 'مبلّغ غير معروف')
                : (item['screen']?.toString().trim().isNotEmpty == true ? item['screen'].toString() : 'مقترحات الطلاب');
            return DataRow(cells: [
              DataCell(_typeBadge(item)),
              DataCell(SizedBox(width: 150, child: Text(sender, maxLines: 2, overflow: TextOverflow.ellipsis))),
              DataCell(SizedBox(width: 270, child: Text(shortMessage.isEmpty ? _title(item) : shortMessage, maxLines: 2, overflow: TextOverflow.ellipsis))),
              DataCell(Text(_dateLabel(item['createdAt']))),
              DataCell(_statusBadge(item)),
              DataCell(_recordActions(item)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _typeBadge(Map<String, dynamic> item) {
    final type = _typeLabel(item);
    final color = type == 'بلاغ دردشة'
        ? Colors.deepPurple
        : type == 'بلاغ عام' ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Text(type, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _statusBadge(Map<String, dynamic> item) {
    final color = _statusColor(context, item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Text(_statusLabel(item), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '—';
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  Widget _mobileRecord(Map<String, dynamic> item) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _typeBadge(item),
          _statusBadge(item),
          Text(_dateLabel(item['createdAt']), style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 10),
        Text(_title(item), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(_message(item), maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text(
          _source(item) == 'chat'
              ? 'المبلّغ: ${item['reporterName'] ?? 'غير معروف'}'
              : 'الطالب: ${item['studentName'] ?? 'غير معروف'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(
          onPressed: _busy.contains(_busyKey(item)) ? null : () => _openDetails(item),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('التفاصيل والإجراء'),
        )),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    final width = MediaQuery.sizeOf(context).width;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(width < 600 ? 14 : 24),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('المقترحات والبلاغات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ])),
            IconButton(tooltip: 'تحديث القائمة', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            _viewCard(
              view: 'solved', title: 'تم الحل', subtitle: 'السجلات التي تمت معالجتها',
              icon: Icons.check_circle_outline, count: _countWhere(_isSolved), color: Colors.green,
            ),
            const SizedBox(width: 12),
            _viewCard(
              view: 'archived', title: 'الأرشيف', subtitle: 'السجلات المرفوضة أو المؤرشفة',
              icon: Icons.archive_outlined, count: _countWhere(_isArchived), color: Colors.blueGrey,
            ),
          ]),
          const SizedBox(height: 18),
          if (_view != 'current') ...[
            Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(
              onPressed: () => setState(() => _view = 'current'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('العودة للسجلات الحالية'),
            )),
            const SizedBox(height: 4),
          ],
          Card(
            child: Padding(
              padding: EdgeInsets.all(width < 600 ? 12 : 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: width < 600 ? double.infinity : 330,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'ابحث في الرسالة أو القسم أو المرسل...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty ? null : IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width < 600 ? double.infinity : 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نوع السجل'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('كل الأنواع')),
                        DropdownMenuItem(value: 'suggestion', child: Text('المقترحات فقط')),
                        DropdownMenuItem(value: 'report', child: Text('البلاغات العامة')),
                        DropdownMenuItem(value: 'chat', child: Text('بلاغات الدردشة')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _type = value);
                        }
                      },
                    ),
                  ),
                ]),
                if (_loading && _allItems.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(
                    onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'),
                  )),
                ],
                if (!_loading && items.isEmpty && _error == null) const _EmptyRecords(),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth >= 760) return _desktopTable(items);
                    return Column(children: items.map(_mobileRecord).toList());
                  }),
                ],
                if (_loading && _allItems.isNotEmpty)
                  const LinearProgressIndicator(minHeight: 2),
              ]),
            ),
          ),
        ],
      ),
    );
  }


}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, style: BorderStyle.solid),
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
    ),
    child: Column(children: [
      Icon(Icons.inbox_outlined, size: 34, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 8),
      const Text('لا توجد سجلات في هذا القسم.'),
    ]),
  );
}

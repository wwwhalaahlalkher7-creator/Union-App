import 'package:flutter/material.dart';
import '../../api_service.dart';

class EinoMonitorPage extends StatefulWidget {
  const EinoMonitorPage({super.key, required this.api});
  final ApiService api;
  @override
  State<EinoMonitorPage> createState() => _EinoMonitorPageState();
}

class _EinoMonitorPageState extends State<EinoMonitorPage> {
  int _hours = 24;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _data = {};
  @override
  void initState() { super.initState(); _load(); }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.get('/admin/security/eino-usage?hours=$_hours');
      if (mounted) setState(() => _data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map) : result);
    } catch (e) { if (mounted) { setState(() => _error = e.toString()); } }
    finally { if (mounted) { setState(() => _loading = false); } }
  }

  Widget _metric(String title, String value, IconData icon) => Expanded(child: Card(child: Padding(
    padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon), const SizedBox(height: 10), Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4), Text(title, style: Theme.of(context).textTheme.bodySmall),
    ]))));

  @override
  Widget build(BuildContext context) {
    final summary = _rows(_data['summary']);
    final buckets = _rows(_data['buckets']);
    final total = summary.fold<int>(0, (sum, row) => sum + ((row['eventCount'] as num?)?.toInt() ?? 0));
    final failed = summary.where((r) => ['error', 'failed', 'failure'].contains('${r['eventType'] ?? ''}'.toLowerCase())).fold<int>(0, (s, r) => s + ((r['eventCount'] as num?)?.toInt() ?? 0));
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مراقبة إينو', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5), const Text('مؤشرات الاستخدام والأداء والأخطاء ومزودي الخدمة، دون عرض نصوص المحادثات أو معرفات الطلاب.'),
      ])), IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh))]),
      const SizedBox(height: 12),
      Align(alignment: AlignmentDirectional.centerStart, child: SegmentedButton<int>(
        segments: const [ButtonSegment(value: 1, label: Text('ساعة')), ButtonSegment(value: 24, label: Text('24 ساعة')), ButtonSegment(value: 72, label: Text('3 أيام')), ButtonSegment(value: 168, label: Text('7 أيام'))],
        selected: {_hours}, onSelectionChanged: (s) { setState(() => _hours = s.first); _load(); })),
      if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('تعذر تحميل مراقبة إينو: $_error'), Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')))]))),
      if (_loading && _data.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      if (_data.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [ _metric('الطلبات المسجلة', '$total', Icons.query_stats_outlined), _metric('الطلبات غير الناجحة', '$failed', Icons.error_outline)]),
        const SizedBox(height: 14),
        _section('ملخص الاستخدام', summary, (r) => '${r['eventType'] ?? 'حدث'} • ${r['actorType'] ?? 'غير محدد'}', (r) => 'الطلبات ${r['eventCount'] ?? 0} • متوسط زمن الاستجابة ${r['averageLatencyMs'] ?? 0} ms'),
        _section('الفترات المسجلة', buckets, (r) => '${r['bucketStartedAt'] ?? 'وقت غير معروف'}', (r) => '${r['eventType'] ?? 'حدث'} • ${r['actorType'] ?? 'غير محدد'} • الطلبات ${r['eventCount'] ?? 0} • الزمن الإجمالي ${r['totalLatencyMs'] ?? 0} ms'),
        if (_data['limits'] is Map) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('حدود الاستخدام: نافذة ${(_data['limits'] as Map)['window'] ?? '—'} طلبًا / ${(_data['limits'] as Map)['windowSeconds'] ?? '—'} ثانية؛ يوميًا طالب ${(_data['limits'] as Map)['studentDaily'] ?? '—'}، زائر ${(_data['limits'] as Map)['guestDaily'] ?? '—'}، إجمالي ${(_data['limits'] as Map)['globalDaily'] ?? '—'}.'))),
      ],
    ]));
  }

  Widget _section(String title, List<Map<String, dynamic>> rows, String Function(Map<String,dynamic>) heading, String Function(Map<String,dynamic>) detail) => Padding(
    padding: const EdgeInsets.only(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
      if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('لا توجد بيانات في الفترة المحددة.'))),
      for (final row in rows) Card(child: ListTile(title: Text(heading(row)), subtitle: Text(detail(row), textDirection: TextDirection.rtl))),
    ]));
}


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
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
      : <Map<String, dynamic>>[];

  int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // This is the supported telemetry endpoint and contains aggregated data only.
      final result = await widget.api.get('/admin/security/eino-usage?hours=$_hours');
      if (mounted) setState(() => _data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _metric(String title, String value, IconData icon) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final summary = _rows(_data['summary']);
    final buckets = _rows(_data['buckets']);
    final providerSummary = _rows(_data['providerSummary']);
    final detailBuckets = _rows(_data['detailBuckets']);
    final total = summary.fold<int>(0, (sum, row) => sum + _int(row['eventCount']));
    final totalLatency = buckets.fold<int>(0, (sum, row) => sum + _int(row['totalLatencyMs']));
    final average = total == 0 ? 0 : (totalLatency / total).round();
    final limits = _data['limits'] is Map ? Map<String, dynamic>.from(_data['limits'] as Map) : <String, dynamic>{};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مراقبة إينو', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('استخدام وأداء Eino حسب نوع الحدث والدور، دون عرض نصوص المحادثات أو معرفات الطلاب.'),
          ])),
          IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('ساعة')),
              ButtonSegment(value: 24, label: Text('24 ساعة')),
              ButtonSegment(value: 72, label: Text('3 أيام')),
              ButtonSegment(value: 168, label: Text('7 أيام')),
            ],
            selected: {_hours},
            onSelectionChanged: _loading ? null : (selection) { setState(() => _hours = selection.first); _load(); },
          ),
        ),
        if (_error != null)
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('تعذر تحميل بيانات مراقبة إينو: $_error'),
            Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))),
          ]))),
        if (_loading && _data.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        if (!_loading && _error == null && _data.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لم يُرجع الخادم بيانات مراقبة لهذه الفترة.'))),
        if (_data.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            _metric('الأحداث المسجلة', '$total', Icons.query_stats_outlined),
            const SizedBox(width: 8),
            _metric('متوسط زمن الاستجابة', '$average ms', Icons.speed_outlined),
          ]),
          const SizedBox(height: 16),
          Text('ملخص أنواع الأحداث', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (summary.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('لا توجد أحداث مسجلة في الفترة المحددة.'))),
          for (final row in summary)
            Card(child: ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: Text('${row['eventType'] ?? 'حدث غير معروف'}'),
              subtitle: Text('الفئة: ${row['actorType'] ?? 'غير معروفة'} • متوسط زمن الاستجابة: ${_int(row['averageLatencyMs'])} ms'),
              trailing: Text('${_int(row['eventCount'])} حدث', style: const TextStyle(fontWeight: FontWeight.w700)),
            )),
          const SizedBox(height: 14),
          Text('الاستخدام حسب المهمة والمزوّد', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (providerSummary.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('تفصيل المزوّد والمهمة سيظهر للطلبات الجديدة بعد تطبيق ترحيل قاعدة البيانات.'))),
          for (final row in providerSummary)
            Card(child: ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text('${row['capability'] ?? 'مهمة غير معروفة'} • ${row['provider'] ?? 'مزوّد غير معروف'}'),
              subtitle: Text('النموذج: ${row['model'] ?? '—'} • متوسط الاستجابة: ${_int(row['averageLatencyMs'])} ms • الحالة: ${row['status'] ?? '—'}'),
              isThreeLine: true,
              trailing: Text('${_int(row['eventCount'])} طلب', style: const TextStyle(fontWeight: FontWeight.w700)),
            )),
          const SizedBox(height: 14),
          Text('آخر الساعات حسب المزوّد (بيانات مجمّعة)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (detailBuckets.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('لا توجد فترات مجمّعة بعد لتفصيل المزوّد.'))),
          for (final row in detailBuckets.take(40))
            Card(child: ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text('${row['capability'] ?? '—'} • ${row['provider'] ?? '—'} / ${row['model'] ?? '—'}'),
              subtitle: Text('${row['bucketStartedAt'] ?? 'وقت غير معروف'} • ${row['status'] ?? '—'} • آخر حدث ${row['lastEventAt'] ?? '—'}'),
              isThreeLine: true,
              trailing: Text('${_int(row['eventCount'])} طلب\n${_int(row['averageLatencyMs'])} ms', textAlign: TextAlign.end),
            )),
          const SizedBox(height: 14),
          Text('آخر الساعات المسجلة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (buckets.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('لا توجد بيانات زمنية متاحة.'))),
          for (final row in buckets.take(100))
            Card(child: ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text('${row['eventType'] ?? 'حدث غير معروف'} • ${row['actorType'] ?? 'غير معروف'}'),
              subtitle: Text('${row['bucketStartedAt'] ?? 'وقت غير معروف'}\nآخر حدث: ${row['lastEventAt'] ?? '—'}'),
              isThreeLine: true,
              trailing: Text('${_int(row['eventCount'])} حدث\n${row['totalLatencyMs'] ?? 0} ms', textAlign: TextAlign.end),
            )),
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('حدود الاستخدام', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('نافذة الاستخدام: ${limits['window'] ?? '—'} طلبًا خلال ${limits['windowSeconds'] ?? '—'} ثانية.'),
            Text('الحد اليومي للطالب: ${limits['studentDaily'] ?? '—'}.'),
            Text('الحد اليومي للزائر: ${limits['guestDaily'] ?? '—'}.'),
            Text('الحد اليومي العام: ${limits['globalDaily'] ?? '—'}.'),
          ]))),
          const SizedBox(height: 8),
          const Text('الخصوصية: بيانات المراقبة مجمّعة ولا تتضمن نصوص المحادثات أو معرفات الطلاب أو عناوين IP.'),
        ],
      ]),
    );
  }
}

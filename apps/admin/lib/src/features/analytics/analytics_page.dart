import 'package:flutter/material.dart';

import '../../api_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.api});
  final ApiService api;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _number(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.get('/admin/analytics/overview');
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = (_data['counts'] is Map)
        ? Map<String, dynamic>.from(_data['counts'] as Map)
        : <String, dynamic>{};
    final cards = <({String title, String key, IconData icon})>[
      (title: 'الطلاب', key: 'students', icon: Icons.school_outlined),
      (title: 'الطلاب النشطون', key: 'activeStudents', icon: Icons.verified_user_outlined),
      (title: 'حسابات الموظفين', key: 'staffUsers', icon: Icons.manage_accounts_outlined),
      (title: 'الأخبار', key: 'contentNews', icon: Icons.article_outlined),
      (title: 'الفعاليات', key: 'contentEvents', icon: Icons.event_outlined),
      (title: 'الإنجازات', key: 'contentAchievements', icon: Icons.emoji_events_outlined),
      (title: 'المواد النشطة', key: 'activeMaterials', icon: Icons.menu_book_outlined),
      (title: 'صفوف الجداول', key: 'scheduleRows', icon: Icons.calendar_month_outlined),
      (title: 'التعليقات', key: 'comments', icon: Icons.forum_outlined),
      (title: 'عناصر السوق', key: 'marketItems', icon: Icons.storefront_outlined),
      (title: 'البلاغات', key: 'feedbackReports', icon: Icons.report_outlined),
      (title: 'بلاغات الدردشة', key: 'chatReports', icon: Icons.chat_bubble_outline),
    ];
    final probe = _data['databaseProbe'] is Map
        ? Map<String, dynamic>.from(_data['databaseProbe'] as Map)
        : <String, dynamic>{};
    final auditDaily = _rows(_data['auditDaily']);
    final auditByResource = _rows(_data['auditByResource']);
    final authFailures = _rows(_data['authFailures']);
    final driveSync = _rows(_data['driveSync']);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مراقبة النظام', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('بيانات تشغيلية تفيد التطوير: نمو الجداول، نشاط التدقيق، أحداث الدخول، ومزامنة Drive.'),
              if (_data['generatedAt'] != null)
                Padding(padding: const EdgeInsets.only(top: 5), child: Text('آخر تحديث: ${_data['generatedAt']}', style: theme.textTheme.bodySmall)),
            ])),
            IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث البيانات', icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 14),
          if (_loading && _data.isEmpty) const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('تعذّر تحميل بيانات المراقبة: $_error'),
            Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))),
          ]))),
          if (counts.isNotEmpty) LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 620 ? 3 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final card in cards)
                SizedBox(width: width, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(card.icon, color: theme.colorScheme.primary, size: 23),
                  const SizedBox(height: 10),
                  Text('${_number(counts[card.key])}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(card.title, style: theme.textTheme.bodySmall),
                ])))),
            ]);
          }),
          const SizedBox(height: 16),
          _SectionCard(title: 'فحص D1 التشخيصي', icon: Icons.storage_outlined, child: Column(children: [
            _MetricLine(label: 'عدد الجداول المكتشفة', value: '${_number(probe['tableCount'])}'),
            _MetricLine(label: 'زمن استعلام الفحص (ms)', value: '${_number(probe['probeDurationMs'])}'),
            _MetricLine(label: 'الصفوف المقروءة في استعلام الفحص', value: '${_number(probe['probeRowsRead'])}'),
            _MetricLine(label: 'الصفوف المكتوبة في استعلام الفحص', value: '${_number(probe['probeRowsWritten'])}'),
            const SizedBox(height: 8),
            Text('${probe['note'] ?? 'لا تتوفر تفاصيل إضافية.'}', style: theme.textTheme.bodySmall),
          ])),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _CloudflareWorkerMonitor(api: widget.api),
          const SizedBox(height: 12),
          _SectionCard(title: 'نشاط سجل التدقيق — آخر 7 أيام', icon: Icons.receipt_long_outlined, child: _DailyBars(rows: auditDaily)),
          const SizedBox(height: 12),
          _SectionCard(title: 'أكثر العمليات الإدارية تكرارًا', icon: Icons.query_stats_outlined, child: auditByResource.isEmpty
            ? const Text('لا توجد عمليات تدقيق مسجلة خلال الفترة.')
            : Column(children: [for (final row in auditByResource) _MetricLine(label: '${row['resource'] ?? '—'} · ${row['action'] ?? '—'}', value: '${_number(row['count'])}') ])),
          const SizedBox(height: 12),
          _SectionCard(title: 'أحداث المصادقة — آخر 7 أيام', icon: Icons.lock_clock_outlined, child: authFailures.isEmpty
            ? const Text('لا توجد أحداث مصادقة مسجلة خلال الفترة.')
            : Column(children: [for (final row in authFailures) _MetricLine(label: '${row['event'] ?? '—'}', value: '${_number(row['count'])}') ])),
          const SizedBox(height: 12),
          _SectionCard(title: 'نتائج مزامنة Drive — آخر 30 يومًا', icon: Icons.cloud_sync_outlined, child: driveSync.isEmpty
            ? const Text('لا توجد عمليات مزامنة مسجلة خلال الفترة.')
            : Column(children: [for (final row in driveSync) _MetricLine(label: '${row['status'] ?? 'غير معروف'}', value: '${_number(row['count'])}') ])),
          const SizedBox(height: 16),
          const Text('حدود القياس: هذه بيانات التطبيق وقاعدة البيانات وسجل التدقيق. لا تمثل إجمالي طلبات Worker أو استهلاك CPU أو فاتورة حساب Cloudflare؛ هذه تتطلب ربط Cloudflare Analytics API أو Analytics Engine بشكل مستقل.'),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 12),
      child,
    ]),
  ));
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Expanded(child: Text(label)), const SizedBox(width: 12), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
  );
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('لا توجد عمليات تدقيق مسجلة خلال الفترة.');
    final max = rows.map((row) => row['count'] is num ? (row['count'] as num).toInt() : 0).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(children: [for (final row in rows) Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text('${row['day'] ?? '—'}')), Text('${row['count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800))]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (_number(row['count']) / max).clamp(0, 1).toDouble(), minHeight: 7)),
      ]),
    )]);
  }

  int _number(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}


class _CloudflareWorkerMonitor extends StatefulWidget {
  const _CloudflareWorkerMonitor({required this.api});
  final ApiService api;

  @override
  State<_CloudflareWorkerMonitor> createState() => _CloudflareWorkerMonitorState();
}

class _CloudflareWorkerMonitorState extends State<_CloudflareWorkerMonitor> {
  int _hours = 24;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.get('/admin/analytics/cloudflare-worker?hours=$_hours');
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cpu(Object? value) {
    if (value == null) return '—';
    final us = value is num ? value.toDouble() : double.tryParse('$value');
    if (us == null) return '—';
    if (us >= 1000) return '${(us / 1000).toStringAsFixed(2)} ms';
    return '${us.toStringAsFixed(0)} µs';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data['summary'] is Map
        ? Map<String, dynamic>.from(_data['summary'] as Map)
        : <String, dynamic>{};
    final rows = _rows(_data['rows']);
    final configured = _data['configured'] == true;
    final theme = Theme.of(context);

    return _SectionCard(
      title: 'استهلاك Cloudflare Worker',
      icon: Icons.cloud_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('بيانات تشغيلية مباشرة من Cloudflare: عدد الطلبات والأخطاء والطلبات الفرعية ومئينات زمن CPU.'),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('ساعة')),
              ButtonSegment(value: 24, label: Text('24 ساعة')),
              ButtonSegment(value: 168, label: Text('7 أيام')),
              ButtonSegment(value: 720, label: Text('30 يومًا')),
            ],
            selected: {_hours},
            onSelectionChanged: _loading ? null : (value) { setState(() => _hours = value.first); _load(); },
          ),
        ),
        if (_loading && _data.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text('تعذر تحميل بيانات Cloudflare: $_error'),
          Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))),
        ],
        if (!_loading && _error == null && !configured) ...[
          const SizedBox(height: 8),
          const Text('التكامل غير مفعّل بعد. أضف الأسرار CF_ANALYTICS_ACCOUNT_ID وCF_ANALYTICS_API_TOKEN إلى إعدادات النشر. استخدم رمزًا منفصلًا بأقل صلاحية لازمة: Account Analytics Read.'),
          const SizedBox(height: 6),
          Text('${_data['message'] ?? ''}', style: theme.textTheme.bodySmall),
        ],
        if (configured) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MiniMetric(title: 'طلبات Worker', value: '${_int(summary['requests'])}', icon: Icons.sync_alt_outlined),
            _MiniMetric(title: 'أخطاء Worker', value: '${_int(summary['errors'])}', icon: Icons.error_outline),
            _MiniMetric(title: 'طلبات فرعية', value: '${_int(summary['subrequests'])}', icon: Icons.call_split_outlined),
            _MiniMetric(title: 'نسبة الأخطاء', value: '${summary['errorRatePercent'] ?? 0}%', icon: Icons.percent_outlined),
          ]),
          const SizedBox(height: 10),
          if (rows.isEmpty) const Text('لا توجد بيانات ضمن الفترة المحددة.'),
          for (final row in rows.take(50))
            Card(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.monitor_heart_outlined),
                title: Text('${row['datetime'] ?? 'وقت غير متاح'}'),
                subtitle: Text('الحالة: ${row['status'] ?? '—'} • CPU P50: ${_cpu(row['cpuTimeP50'])} • CPU P99: ${_cpu(row['cpuTimeP99'])}'),
                isThreeLine: true,
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('طلبات ${_int(row['requests'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('أخطاء ${_int(row['errors'])}'),
                ]),
              ),
            ),
          const SizedBox(height: 6),
          Text('${_data['note'] ?? 'مقاييس تشغيلية وليست فاتورة Cloudflare.'}', style: theme.textTheme.bodySmall),
        ],
      ]),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

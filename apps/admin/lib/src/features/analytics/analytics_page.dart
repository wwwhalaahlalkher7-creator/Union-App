import 'package:flutter/material.dart';
import '../../api_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.api});
  final ApiService api;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _days = 7;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.get('/admin/analytics/overview?days=$_days');
      if (!mounted) { return; }
      setState(() { _data = result; _loading = false; });
    } catch (error) {
      if (!mounted) { return; }
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  List<Map<String, dynamic>> _rows(String key) {
    final value = _data[key];
    if (value is! List) { return const []; }
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> _routeRows(Map<String, dynamic> resources, String key) {
    final top = resources['topConsumers'];
    if (top is! Map) { return const []; }
    final rows = top[key];
    if (rows is! List) { return const []; }
    return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(child: Text('التحليلات والاستخدام', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            DropdownButton<int>(
              value: _days,
              onChanged: _loading ? null : (value) { if (value != null) { setState(() => _days = value); } _load(); },
              items: const [
                DropdownMenuItem(value: 1, child: Text('24 ساعة')),
                DropdownMenuItem(value: 7, child: Text('7 أيام')),
                DropdownMenuItem(value: 30, child: Text('30 يومًا')),
              ],
            ),
            IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 6),
          Text('إحصاءات مجمّعة من التطبيق والموقع. لا تعرض معرّفات الجلسات أو بيانات الحسابات.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (_loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (!_loading && _error != null) _ErrorPanel(message: _error!, onRetry: _load),
          if (!_loading && _error == null) ...[
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 4 : constraints.maxWidth >= 460 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
              final active = _data['activeSessions'] is Map ? Map<String, dynamic>.from(_data['activeSessions'] as Map) : <String, dynamic>{};
              final cards = <_Metric>[
                _Metric('إجمالي الأحداث', _int(_data['totalEvents']), Icons.insights_outlined),
                _Metric('نشطون يوميًا', _int(active['daily']), Icons.today_outlined),
                _Metric('نشطون أسبوعيًا', _int(active['weekly']), Icons.date_range_outlined),
                _Metric('نشطون شهريًا', _int(active['monthly']), Icons.calendar_month_outlined),
                _Metric('جلسات جديدة', _int(_data['newSessions']), Icons.person_add_alt_1_outlined),
              ];
              return Wrap(spacing: 10, runSpacing: 10, children: cards.map((metric) => SizedBox(width: width, child: _MetricCard(metric: metric))).toList());
            }),
            const SizedBox(height: 18),
            _SectionCard(title: 'مصدر الاستخدام', subtitle: 'جلسات نشطة خلال الفترة المختارة', child: _BarRows(rows: _rows('platforms'), labelKey: 'platform', countKey: 'count', labels: const {'app': 'التطبيق', 'website': 'الموقع'})),
            const SizedBox(height: 12),
            _SectionCard(title: 'الأقسام الأكثر استخدامًا', subtitle: 'حسب عدد أحداث العرض المسجلة', child: _BarRows(rows: _rows('sections'), labelKey: 'section', countKey: 'count', labels: const {
              'home': 'الرئيسية', 'news': 'الأخبار', 'events': 'الفعاليات', 'activities': 'الأنشطة', 'achievements': 'الإنجازات', 'materials': 'المواد الدراسية', 'schedule': 'الجداول', 'student': 'الطلاب والملف الشخصي', 'tools': 'الأدوات', 'favorites': 'المفضلة', 'recent': 'الأخيرة', 'notifications': 'الإشعارات', 'eino': 'إينو', 'chat': 'الدردشة', 'market': 'السوق', 'settings': 'الإعدادات', 'more': 'المزيد', 'media': 'الإعلام', 'website': 'صفحات الموقع', 'other': 'أخرى',
            })),
            const SizedBox(height: 12),
            _SectionCard(title: 'أنواع الأحداث', subtitle: 'ملخص ما تم تسجيله', child: _BarRows(rows: _rows('eventTypes'), labelKey: 'eventName', countKey: 'count', labels: const {'page_view': 'مشاهدة صفحة', 'screen_view': 'فتح شاشة', 'session_start': 'بدء جلسة', 'content_open': 'فتح محتوى', 'file_open': 'فتح ملف', 'search': 'بحث', 'operation_success': 'عملية ناجحة', 'operation_failure': 'عملية فاشلة', 'offline_use': 'استخدام دون اتصال'})),
            const SizedBox(height: 12),
            const SizedBox(height: 18),
            _SectionCard(title: 'استهلاك الخادم والموارد', subtitle: 'طلبات الخادم وعمليات D1 تقديرية بعينة 10% لتقليل استهلاك D1؛ طلبات R2 المسجلة تُجمع كاملة عبر مسارات الوسائط', child: Builder(builder: (context) {
              final resources = _data['resources'] is Map ? Map<String, dynamic>.from(_data['resources'] as Map) : <String, dynamic>{};
              final period = resources['period'] is Map ? Map<String, dynamic>.from(resources['period'] as Map) : <String, dynamic>{};
              final r2 = resources['r2'] is Map ? Map<String, dynamic>.from(resources['r2'] as Map) : <String, dynamic>{};
              String bytes(Object? value) {
                final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
                if (n >= 1024 * 1024 * 1024) { return '${(n / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB'; }
                if (n >= 1024 * 1024) { return '${(n / (1024 * 1024)).toStringAsFixed(2)} MiB'; }
                if (n >= 1024) { return '${(n / 1024).toStringAsFixed(1)} KiB'; }
                return '${n.round()} B';
              }
              final metrics = <_Metric>[
                _Metric('طلبات الخادم', _int(period['serverRequests']), Icons.dns_outlined),
                _Metric('متوسط الاستجابة', _int(period['averageResponseMs']), Icons.speed_outlined),
                _Metric('أخطاء الخادم 5xx', _int(period['serverErrors']), Icons.error_outline),
                _Metric('عمليات D1', _int(period['d1Operations']), Icons.storage_outlined),
                _Metric('صفوف قراءة D1 (المعلنة)', _int(period['d1RowsRead']), Icons.table_rows_outlined),
                _Metric('صفوف D1 المكتوبة', _int(period['d1RowsWritten']), Icons.edit_note_outlined),
                _Metric('طلبات R2 المسجلة', _int(period['r2Operations']), Icons.cloud_outlined),
              ];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 3 : constraints.maxWidth >= 440 ? 2 : 1;
                  final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
                  return Wrap(spacing: 8, runSpacing: 8, children: metrics.map((m) => SizedBox(width: width, child: _MetricCard(metric: m))).toList());
                }),
                const SizedBox(height: 12),
                Text('R2: تخزين الوسائط الحالي ${bytes(r2['currentStorageBytes'])} من ${bytes(r2['configuredStorageLimitBytes'])}.', style: Theme.of(context).textTheme.bodyMedium),
                Text('R2: قراءة ${bytes(period['r2ReadBytes'])} • كتابة ${bytes(period['r2WrittenBytes'])} • عمليات رفع الوسائط المسجلة لهذا الشهر ${_int(r2['monthlyClassARequests'])}.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                _TopRoutes(title: 'أكثر 3 مسارات استهلاكًا لطلبات الخادم', rows: _routeRows(resources, 'serverRequests'), valueLabel: (r) => '${_int(r['count'])} طلب'),
                const SizedBox(height: 10),
                _TopRoutes(title: 'أكثر 3 مسارات استهلاكًا لعمليات D1', rows: _routeRows(resources, 'd1Operations'), valueLabel: (r) => '${_int(r['count'])} عملية'),
                const SizedBox(height: 10),
                _TopRoutes(title: 'أكثر 3 مسارات استهلاكًا لطلبات R2', rows: _routeRows(resources, 'r2Operations'), valueLabel: (r) => '${_int(r['count'])} عملية • ${bytes(r['bytes'])}'),
                const SizedBox(height: 8),
                Text('تنبيه: تقديرات الخادم وD1 تستخدم عينة مرجحة 10%. عمليات R2 تُسجل كاملة عبر مسارات الوسائط. هذه ليست فاتورة Cloudflare، وحجم R2 يعتمد على سجل الوسائط داخل التطبيق فقط.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]);
            })),
            const SizedBox(height: 12),
            _SectionCard(title: 'حالة التسجيل', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _InfoLine(label: 'عمليات فاشلة مسجلة', value: '${_int(_data['failedOperations'])}'),
              const SizedBox(height: 6),
              const Text('لا تُسجّل هذه النسخة كلمات المرور أو نصوص البحث أو محتوى الملفات أو عناوين IP. وتُحذف الأحداث بعد 90 يومًا عند تفعيل مهمة التنظيف المجدولة في الـBackend.', style: TextStyle(height: 1.4)),
            ])),
          ],
        ],
      ),
    );
  }
}

class _TopRoutes extends StatelessWidget {
  const _TopRoutes({required this.title, required this.rows, required this.valueLabel});
  final String title;
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) valueLabel;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    if (rows.isEmpty) const Text('لا توجد بيانات مسجلة لهذه الفترة بعد.'),
    for (var i = 0; i < rows.length; i++) ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 13, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
      title: Text('${rows[i]['route'] ?? 'مسار غير معروف'}', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(valueLabel(rows[i]), style: Theme.of(context).textTheme.labelMedium),
    ),
  ]);
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final int value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
    Icon(metric.icon, size: 27, color: Theme.of(context).colorScheme.primary),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(metric.label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), Text(metric.value.toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))])),
  ])));
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))],
    const SizedBox(height: 14), child,
  ])));
}

class _BarRows extends StatelessWidget {
  const _BarRows({required this.rows, required this.labelKey, required this.countKey, required this.labels});
  final List<Map<String, dynamic>> rows;
  final String labelKey;
  final String countKey;
  final Map<String, String> labels;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) { return const Text('لا توجد بيانات مسجلة لهذه الفترة.'); }
    final max = rows.map((row) => row[countKey] is num ? (row[countKey] as num).toInt() : 0).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(children: rows.map((row) {
      final key = row[labelKey]?.toString() ?? 'other';
      final count = row[countKey] is num ? (row[countKey] as num).toInt() : 0;
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(labels[key] ?? key)), Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.w600))]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: count / max, minHeight: 7)),
      ]));
    }).toList());
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]);
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
    const Icon(Icons.cloud_off_outlined, size: 36),
    const SizedBox(height: 8),
    const Text('تعذّر تحميل التحليلات', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    const Text('تأكد من نشر ترحيل قاعدة البيانات وتحديث الـBackend قبل استخدام هذه الشاشة.'),
    const SizedBox(height: 8),
    Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    const SizedBox(height: 10),
    FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
  ])));
}

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

  int _value(String key) {
    final value = _data[key];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.getDashboardOverview();
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = <({String title, String key, IconData icon})>[
      (title: 'إجمالي الطلاب', key: 'students', icon: Icons.school_outlined),
      (title: 'الطلاب النشطون', key: 'activeStudents', icon: Icons.verified_user_outlined),
      (title: 'إجمالي الموظفين', key: 'staff', icon: Icons.manage_accounts_outlined),
      (title: 'الموظفون النشطون', key: 'activeStaff', icon: Icons.badge_outlined),
      (title: 'الأخبار', key: 'news', icon: Icons.article_outlined),
      (title: 'المواد النشطة', key: 'materials', icon: Icons.menu_book_outlined),
      (title: 'التعليقات الظاهرة', key: 'visibleComments', icon: Icons.forum_outlined),
      (title: 'الإشعارات والإعلانات', key: 'announcements', icon: Icons.notifications_outlined),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إحصاءات النظام', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('ملخص إجمالي من واجهة لوحة المعلومات المدعومة في الخادم؛ لا يعرض تحليلات استخدام تفصيلية غير متاحة في عقد API الحالي.'),
          ])),
          IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        if (_loading && _data.isEmpty) const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator())),
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('تعذر تحميل إحصاءات النظام: $_error'),
          Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))),
        ]))),
        if (_data.isNotEmpty)
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 540 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final metric in metrics)
                SizedBox(width: width, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(metric.icon, size: 28, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 14),
                  Text('${_value(metric.key)}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(metric.title, style: Theme.of(context).textTheme.bodyMedium),
                ])))),
            ]);
          }),
        if (_data.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 18), child: Text('تتحدّث هذه الأرقام عند إعادة تحميل الصفحة. صلاحيات قراءة البيانات يقررها الخادم بحسب دور المستخدم.')),
      ]),
    );
  }
}

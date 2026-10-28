import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api_service.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key, required this.api});
  final ApiService api;

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> _audit = [];
  List<Map<String, dynamic>> _auth = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.get('/admin/audit-logs?limit=100'),
        widget.api.get('/admin/security/auth-events?limit=100'),
      ]);
      if (!mounted) return;
      setState(() {
        _audit = _rows(results[0]['data']);
        _auth = _rows(results[1]['data']);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _pretty(String value) {
    const labels = <String, String>{
      'create': 'إنشاء سجل',
      'update': 'تعديل سجل',
      'delete': 'حذف سجل',
      'send': 'إرسال',
      'change_password': 'تغيير كلمة المرور',
      'login_failed': 'فشل تسجيل الدخول',
      'login_locked': 'قفل تسجيل الدخول',
      'password_change_failed': 'فشل تغيير كلمة المرور',
      'password_change_locked': 'قفل تغيير كلمة المرور',
      'password_changed': 'تغيير كلمة المرور',
      'password_reset_by_admin': 'إعادة تعيين كلمة المرور إداريًا',
    };
    return labels[value] ?? value.replaceAll('_', ' ');
  }

  dynamic _redact(dynamic value) {
    final sensitive = RegExp(
      r'(password|token|secret|authorization|cookie|credential|api.?key)',
      caseSensitive: false,
    );
    if (value is Map) {
      return value.map((key, item) {
        final name = key.toString();
        if (sensitive.hasMatch(name)) return MapEntry(name, '[محجوب]');
        if (name.toLowerCase() == 'metadata_json' && item is String) {
          try {
            return MapEntry(name, _redact(jsonDecode(item)));
          } catch (_) {
            return MapEntry(name, '[تفاصيل مخفية: تعذر التحقق من بنيتها]');
          }
        }
        return MapEntry(name, _redact(item));
      });
    }
    if (value is List) return value.map(_redact).toList();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return _redact(jsonDecode(trimmed));
        } catch (_) {
          return value;
        }
      }
    }
    return value;
  }

  String _safeDetails(Map<String, dynamic> item) {
    final safe = _redact(item) as Map;
    return safe.entries
        .map((entry) => '${entry.key}: ${entry.value ?? '—'}')
        .join('\n');
  }

  Widget _logList(List<Map<String, dynamic>> items, {required bool auth}) {
    if (_loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد سجلات لعرضها.'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final action = (item[auth ? 'event_type' : 'action'] ?? 'حدث')
            .toString();
        final actor = (item['actor_name'] ??
                item['actor_user_id'] ??
                item['actor_email'] ??
                item['actor_id'] ??
                'حساب غير معروف')
            .toString();
        final time = (item['created_at'] ?? 'وقت غير معروف').toString();
        final detail = auth
            ? '${item['actor_type'] ?? '—'} • ${item['role_name'] ?? '—'}'
            : '${item['resource_type'] ?? '—'}'
                '${item['resource_id'] == null ? '' : ' • ${item['resource_id']}'}';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                auth ? Icons.login_outlined : Icons.history_outlined,
              ),
            ),
            title: Text(_pretty(action), textDirection: TextDirection.rtl),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '$actor\n$detail\n$time',
                textDirection: TextDirection.rtl,
              ),
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'التفاصيل',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('تفاصيل السجل'),
                  content: SingleChildScrollView(
                    child: SelectableText(
                      _safeDetails(item),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الأمان وسجل التدقيق',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'مراجعة العمليات الإدارية ومحاولات المصادقة التي يسجلها الخادم.',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  tooltip: 'تحديث السجلات',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'السجل للقراءة فقط. تُحجب الحقول الحساسة قبل عرض تفاصيل السجلات.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: MaterialBanner(
                content: Text('تعذر تحميل السجلات: $_error'),
                actions: [
                  TextButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'سجل العمليات'),
              Tab(text: 'أحداث المصادقة'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _logList(_audit, auth: false),
                _logList(_auth, auth: true),
              ],
            ),
          ),
        ],
      );
}

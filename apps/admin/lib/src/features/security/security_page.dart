import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api_service.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key, required this.api});
  final ApiService api;

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  List<Map<String, dynamic>> _audit = [];
  List<Map<String, dynamic>> _auth = [];
  List<Map<String, dynamic>> _imports = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  List<Map<String, dynamic>> _rows(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.api.get('/admin/audit-logs?limit=100'),
        widget.api.get('/admin/security/auth-events?limit=100'),
        widget.api.get('/admin/imports?limit=100'),
      ]);
      if (!mounted) { return; }
      setState(() { _audit = _rows(results[0]['data']); _auth = _rows(results[1]['data']); _imports = _rows(results[2]['data']); });
    } catch (e) {
      if (mounted) { setState(() => _error = e.toString()); }
    } finally { if (mounted) { setState(() => _loading = false); } }
  }

  String _importStatus(dynamic value) => switch ('$value') {
    'committed' => 'تم الاعتماد', 'rolled_back' => 'تم التراجع', 'review' => 'قيد المراجعة',
    'expired' => 'انتهت المهلة', 'failed' => 'فشلت العملية', _ => 'غير معروف',
  };

  Future<void> _openImport(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) { return; }
    try {
      final response = await widget.api.get('/admin/imports/$id');
      if (!mounted) { return; }
      final detail = Map<String, dynamic>.from(response);
      final rawRows = detail['reviewed'];
      final rows = rawRows is List ? rawRows.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList() : <Map<String, dynamic>>[];
      final isStudents = '${detail['import_type']}' == 'students';
      final status = '${detail['status'] ?? item['status']}';
      var subjects = <Map<String, dynamic>>[];
      if (!isStudents) {
        try {
          final result = await widget.api.get('/admin/subjects?limit=100');
          final raw = result['data'];
          if (raw is List) { subjects = raw.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList(); }
        } catch (_) {}
      }
      final editedRows = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      var editing = false;
      var saving = false;
      final action = await showDialog<String?>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) {
        return AlertDialog(
          title: Text(isStudents ? 'مراجعة استيراد الطلاب' : 'مراجعة استيراد الجدول'),
          content: SizedBox(width: 680, child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 520), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('القسم: ${detail['department_name'] ?? detail['department_id'] ?? '—'} • الفصل: ${detail['semester_name'] ?? detail['semester_id'] ?? '—'}'),
            Text('الحالة: ${_importStatus(status)}'),
            Text('وقت الاعتماد: ${detail['committed_at'] ?? '—'}'),
            const Divider(),
            Expanded(child: editedRows.isEmpty ? const Center(child: Text('لا توجد نسخة مراجعة محفوظة لهذه العملية.')) : ListView.separated(itemCount: editedRows.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
              final r = editedRows[i];
              if (!editing) {
                final title = isStudents ? '${r['fullName'] ?? r['full_name'] ?? 'اسم غير محدد'}' : '${r['subjectName'] ?? r['subject_name'] ?? r['subjectId'] ?? r['subject_id'] ?? 'مادة غير محددة'}';
                final subtitle = isStudents ? 'الرقم الجامعي: ${r['studentNumber'] ?? r['student_number'] ?? '—'} • البريد: ${r['email'] ?? '—'}' : '${_day(r['dayOfWeek'] ?? r['day_of_week'])} • ${r['startTime'] ?? r['start_time'] ?? '—'}–${r['endTime'] ?? r['end_time'] ?? '—'}';
                return ListTile(title: Text(title), subtitle: Text(subtitle), dense: true);
              }
              if (isStudents) {
                return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: [
                  Text('الطالب ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextFormField(initialValue: '${r['studentNumber'] ?? r['student_number'] ?? ''}', decoration: const InputDecoration(labelText: 'الرقم الجامعي'), onChanged: (v) => editedRows[i]['studentNumber'] = v),
                  TextFormField(initialValue: '${r['fullName'] ?? r['full_name'] ?? ''}', decoration: const InputDecoration(labelText: 'اسم الطالب'), onChanged: (v) => editedRows[i]['fullName'] = v),
                  TextFormField(initialValue: '${r['email'] ?? ''}', decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), onChanged: (v) => editedRows[i]['email'] = v),
                ]));
              }
              final currentSubject = '${r['subjectId'] ?? r['subject_id'] ?? ''}';
              final currentDay = int.tryParse('${r['dayOfWeek'] ?? r['day_of_week'] ?? 0}') ?? 0;
              return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: [
                Text('الحصة ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(initialValue: subjects.any((s) => '${s['id']}' == currentSubject) ? currentSubject : null, decoration: const InputDecoration(labelText: 'المادة'), items: subjects.where((s) => '${s['department_id']}' == '${detail['department_id']}' && '${s['semester_id']}' == '${detail['semester_id']}').map((s) => DropdownMenuItem(value: '${s['id']}', child: Text('${s['name_ar'] ?? s['name_en'] ?? s['id']}'))).toList(), onChanged: (v) => setDialogState(() { editedRows[i]['subjectId'] = v ?? ''; editedRows[i]['subjectName'] = (subjects.where((s) => '${s['id']}' == v).map((s) => '${s['name_ar'] ?? s['name_en'] ?? s['id']}').toList().isEmpty ? '' : subjects.where((s) => '${s['id']}' == v).map((s) => '${s['name_ar'] ?? s['name_en'] ?? s['id']}').first); })),
                DropdownButtonFormField<int>(initialValue: currentDay.clamp(0, 6).toInt(), decoration: const InputDecoration(labelText: 'اليوم'), items: const [DropdownMenuItem(value:0,child:Text('الأحد')),DropdownMenuItem(value:1,child:Text('الاثنين')),DropdownMenuItem(value:2,child:Text('الثلاثاء')),DropdownMenuItem(value:3,child:Text('الأربعاء')),DropdownMenuItem(value:4,child:Text('الخميس')),DropdownMenuItem(value:5,child:Text('الجمعة')),DropdownMenuItem(value:6,child:Text('السبت'))], onChanged: (v) => setDialogState(() => editedRows[i]['dayOfWeek'] = v ?? 0)),
                Row(children: [Expanded(child: TextFormField(initialValue: '${r['startTime'] ?? r['start_time'] ?? ''}', decoration: const InputDecoration(labelText: 'البداية'), onChanged: (v) => editedRows[i]['startTime'] = v)), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: '${r['endTime'] ?? r['end_time'] ?? ''}', decoration: const InputDecoration(labelText: 'النهاية'), onChanged: (v) => editedRows[i]['endTime'] = v))]),
                Row(children: [Expanded(child: TextFormField(initialValue: '${r['room'] ?? ''}', decoration: const InputDecoration(labelText: 'القاعة'), onChanged: (v) => editedRows[i]['room'] = v)), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: '${r['lecturer'] ?? ''}', decoration: const InputDecoration(labelText: 'المدرّس'), onChanged: (v) => editedRows[i]['lecturer'] = v))]),
              ]));
            })),
          ]))),
          actions: [
            if (status == 'committed' && !editing) TextButton.icon(onPressed: () => setDialogState(() => editing = true), icon: const Icon(Icons.edit_outlined), label: const Text('تعديل البيانات')),
            if (status == 'committed' && editing) TextButton(onPressed: saving ? null : () => setDialogState(() { editedRows..clear()..addAll(rows.map((r) => Map<String, dynamic>.from(r))); editing = false; }), child: const Text('إلغاء التعديل')),
            if (status == 'committed' && editing) FilledButton.icon(onPressed: saving ? null : () async {
              setDialogState(() => saving = true);
              try {
                await widget.api.patch('/admin/imports/$id/records', body: {'records': editedRows});
                if (dialogContext.mounted) { Navigator.pop(dialogContext, 'saved'); }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('تعذر حفظ التعديلات: $e'),
                      backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    ),
                  );
                  setDialogState(() => saving = false);
                }
              }
            }, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'جارٍ الحفظ…' : 'حفظ التعديلات')),
            if (status == 'committed' && !editing) TextButton.icon(onPressed: () => Navigator.pop(dialogContext, 'rollback'), icon: const Icon(Icons.undo), label: const Text('التراجع عن العملية')),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
          ],
        );
      }));
      if (action == 'saved' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات على السجلات المستوردة.')));
        await _load();
        return;
      }
      if (action != 'rollback' || !mounted) { return; }
      final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('تأكيد التراجع عن الاستيراد'),
        content: const Text('سيحاول النظام التراجع عن السجلات التي لم تتغير منذ الاستيراد. إذا تغير أي سجل، فسيُوقف التراجع بالكامل لحماية التعديلات الأحدث.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد التراجع'))],
      ));
      if (confirmed != true || !mounted) { return; }
      try {
        final result = await widget.api.post('/admin/imports/$id/rollback');
        if (!mounted) { return; }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم التراجع عن ${result['rolledBack'] ?? 0} سجل.')));
        await _load();
      } catch (e) {
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر التراجع: $e'), backgroundColor: Theme.of(context).colorScheme.error)); }
      }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح مراجعة العملية: $e'), backgroundColor: Theme.of(context).colorScheme.error)); }
    }
  }

  String _day(dynamic value) {
    final day = int.tryParse('$value') ?? 0;
    return const ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'][day.clamp(0,6).toInt()];
  }

  Widget _importList() {
    if (_loading && _imports.isEmpty) { return const Center(child: CircularProgressIndicator()); }
    if (_imports.isEmpty) { return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('لا توجد عمليات استيراد مسجلة.'))); }
    return ListView.separated(padding: const EdgeInsets.all(16), itemCount: _imports.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
      final item = _imports[index];
      final isStudents = '${item['import_type']}' == 'students';
      return Card(child: ListTile(
        leading: CircleAvatar(child: Icon(isStudents ? Icons.school_outlined : Icons.calendar_month_outlined)),
        title: Text(isStudents ? 'استيراد الطلاب' : 'استيراد الجدول'),
        subtitle: Text('${item['department_name'] ?? item['department_id'] ?? '—'} • ${item['semester_name'] ?? item['semester_id'] ?? '—'}\n${_importStatus(item['status'])} • ${item['created_at'] ?? 'وقت غير معروف'}', textDirection: TextDirection.rtl),
        isThreeLine: true,
        onTap: () => _openImport(item),
      ));
    });
  }

  String _pretty(String value) {
    const names = {
      'create': 'إنشاء', 'update': 'تعديل', 'delete': 'حذف', 'send': 'إرسال',
      'change_password': 'تغيير كلمة المرور', 'login_failed': 'فشل تسجيل الدخول',
      'login_locked': 'قفل تسجيل الدخول', 'password_change_failed': 'فشل تغيير كلمة المرور',
      'password_change_locked': 'قفل تغيير كلمة المرور', 'password_changed': 'تغيير كلمة المرور',
      'password_reset_by_admin': 'إعادة تعيين كلمة المرور إداريًا',
    };
    return names[value] ?? value.replaceAll('_', ' ');
  }

  dynamic _redact(dynamic value) {
    final sensitive = RegExp(
      r'(password|token|secret|authorization|cookie|credential|api.?key)',
      caseSensitive: false,
    );
    if (value is Map) {
      return value.map((key, item) {
        final name = key.toString();
        if (sensitive.hasMatch(name)) { return MapEntry(name, '[محجوب]'); }
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
    if (value is List) { return value.map(_redact).toList(); }
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
    if (_loading && items.isEmpty) { return const Center(child: CircularProgressIndicator()); }
    if (items.isEmpty) { return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('لا توجد سجلات لعرضها.'))); }
    return ListView.separated(
      padding: const EdgeInsets.all(16), itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final action = (item[auth ? 'event_type' : 'action'] ?? 'حدث').toString();
        final actor = (item['actor_name'] ?? item['actor_user_id'] ?? item['actor_email'] ?? 'حساب غير معروف').toString();
        final time = (item['created_at'] ?? 'وقت غير معروف').toString();
        final detail = auth ? '${item['actor_type'] ?? '—'} • ${item['role_name'] ?? '—'}' : '${item['resource_type'] ?? '—'}${item['resource_id'] == null ? '' : ' • ${item['resource_id']}'}';
        return Card(child: ListTile(
          leading: CircleAvatar(child: Icon(auth ? Icons.login_outlined : Icons.history_outlined)),
          title: Text(_pretty(action), textDirection: TextDirection.rtl),
          subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text('$actor\n$detail\n$time', textDirection: TextDirection.rtl)),
          isThreeLine: true,
          trailing: IconButton(tooltip: 'التفاصيل', icon: const Icon(Icons.info_outline), onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تفاصيل السجل'),
              content: SingleChildScrollView(child: SelectableText(_safeDetails(item), textDirection: TextDirection.ltr)),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
            ),
          )),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 20, 12, 8), child: Row(children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الأمان وسجل التدقيق', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        SizedBox(height: 4), Text('مراجعة العمليات الإدارية ومحاولات المصادقة التي يسجلها الخادم.'),
      ])),
      IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث السجلات', icon: const Icon(Icons.refresh)),
    ])),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Card(child: Padding(padding: EdgeInsets.all(12), child: Row(children: [
      Icon(Icons.verified_user_outlined), SizedBox(width: 10), Expanded(child: Text('السجل للقراءة فقط من التطبيق. لا تُعرض كلمات المرور أو الرموز السرية ضمن هذه الشاشة.')),
    ])))),
    if (_error != null) Padding(padding: const EdgeInsets.all(12), child: MaterialBanner(content: Text('تعذر تحميل السجلات: $_error'), actions: [TextButton(onPressed: _load, child: const Text('إعادة المحاولة'))])),
    TabBar(controller: _tabs, tabs: const [Tab(text: 'سجل العمليات'), Tab(text: 'أحداث المصادقة'), Tab(text: 'عمليات الاستيراد')]),
    Expanded(child: TabBarView(controller: _tabs, children: [_logList(_audit, auth: false), _logList(_auth, auth: true), _importList()])),
  ]);
}

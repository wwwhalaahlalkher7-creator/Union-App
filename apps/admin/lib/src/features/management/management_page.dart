import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../api_service.dart';

class ManagementPage extends StatefulWidget {
  const ManagementPage({super.key, required this.api, required this.role});
  final ApiService api;
  final String role;

  @override
  State<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends State<ManagementPage> {
  static const _superAdmin = 'super_admin';
  static const _contentManager = 'content_manager';
  static const _academicManager = 'academic_manager';

  String _tab = 'market';
  bool _loading = false;
  bool _working = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _departments = [];
  Map<String, dynamic> _examIndex = {};
  List<Map<String, dynamic>> _syncRuns = [];

  List<String> get _availableTabs {
    if (widget.role == _superAdmin) return const ['market', 'badges', 'exams'];
    if (widget.role == _contentManager) return const ['market', 'badges'];
    if (widget.role == _academicManager) return const ['exams'];
    return const [];
  }

  @override
  void initState() {
    super.initState();
    final tabs = _availableTabs;
    _tab = tabs.isEmpty ? 'market' : tabs.first;
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    }
    if (value is Map && value['data'] is List) return _rows(value['data']);
    return [];
  }

  String _text(Map<String, dynamic> row, List<String> keys, [String fallback = '—']) {
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  bool _active(Map<String, dynamic> row) => row['active'] == true || row['active'] == 1;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_tab == 'market') {
        final result = await Future.wait([
          widget.api.get('/admin/market-items?limit=100'),
          widget.api.get('/departments'),
        ]);
        if (!mounted) return;
        setState(() {
          _items = _rows(result[0]['data'] ?? result[0]);
          _departments = _rows(result[1]['data'] ?? result[1]);
        });
      } else if (_tab == 'badges') {
        final result = await widget.api.get('/admin/badges?limit=100');
        if (!mounted) return;
        setState(() => _items = _rows(result['data'] ?? result));
      } else {
        final result = await Future.wait([
          widget.api.get('/admin/exams'),
          widget.api.get('/admin/drive/sync-status'),
        ]);
        if (!mounted) return;
        setState(() {
          _examIndex = Map<String, dynamic>.from(result[0]);
          _syncRuns = _rows(result[1]['data'] ?? result[1]);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String value, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: bad ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _saveRecord(Map<String, dynamic> values, {String? id}) async {
    setState(() => _working = true);
    try {
      if (_tab == 'market') {
        if (id == null) {
          await widget.api.post('/admin/market-items', body: values);
        } else {
          await widget.api.patch('/admin/market-items/$id', body: values);
        }
      } else {
        if (id == null) {
          await widget.api.post('/admin/badges', body: values);
        } else {
          await widget.api.patch('/admin/badges/$id', body: values);
        }
      }
      _message(id == null ? 'تمت الإضافة بنجاح.' : 'تم حفظ التعديلات.');
      await _load();
    } catch (error) {
      _message('تعذر حفظ البيانات: $error', bad: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editRecord([Map<String, dynamic>? item]) async {
    final values = _tab == 'market'
        ? await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => _MarketItemEditor(item: item, departments: _departments),
          )
        : await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => _BadgeEditor(item: item),
          );
    if (values == null || !mounted) return;
    await _saveRecord(values, id: item?['id']?.toString());
  }

  Future<void> _toggleActive(Map<String, dynamic> item, bool active) async {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await widget.api.patch('/admin/${_tab == 'market' ? 'market-items' : 'badges'}/$id', body: {'active': active ? 1 : 0});
      _message(active ? 'تم تفعيل السجل.' : 'تم إيقاف السجل.');
      await _load();
    } catch (error) {
      _message('تعذر تغيير الحالة: $error', bad: true);
    }
  }

  Future<void> _deleteMarketItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف عنصر السوق نهائيًا؟'),
        content: Text('سيتم حذف «${_text(item, ['title_ar', 'title_en'])}» من السوق. لا يمكن التراجع عن الحذف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف نهائيًا')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await widget.api.delete('/admin/market-items/$id');
      _message('تم حذف عنصر السوق.');
      await _load();
    } catch (error) {
      _message('تعذر الحذف: $error', bad: true);
    }
  }

  Future<void> _syncDrive() async {
    setState(() => _working = true);
    try {
      await widget.api.post('/admin/drive/sync');
      _message('تم تنفيذ طلب مزامنة Drive.');
      await _load();
    } catch (error) {
      _message('تعذرت مزامنة Drive: $error', bad: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _ensureExamFolder(Map<String, dynamic> subject) async {
    final subjectFolderId = _text(subject, ['subjectFolderId', 'subject_folder_id'], '');
    if (subjectFolderId.isEmpty) return;
    setState(() => _working = true);
    try {
      final result = await widget.api.post('/admin/exams', body: {
        'action': 'ensure-folder',
        'subjectFolderId': subjectFolderId,
      });
      _message(result['existing'] == true ? 'مجلد الامتحانات موجود بالفعل.' : 'تم إنشاء مجلد الامتحانات.');
      await _load();
    } catch (error) {
      _message('تعذر إنشاء مجلد الامتحانات: $error', bad: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _uploadExam(Map<String, dynamic> subject) async {
    final subjectFolderId = _text(subject, ['subjectFolderId', 'subject_folder_id'], '');
    if (subjectFolderId.isEmpty) {
      _message('لم يُرجع الخادم معرّف مجلد المادة. نفّذ مزامنة Drive ثم حاول مجددًا.', bad: true);
      return;
    }
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty || !mounted) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        _message('تعذر قراءة الملف المختار من الجهاز.', bad: true);
        return;
      }
      if (file.size > 20 * 1024 * 1024) {
        _message('الحد الأقصى لحجم ملف الامتحان هو 20 ميجابايت.', bad: true);
        return;
      }
      final name = await _askName('اسم ملف الامتحان', file.name);
      if (name == null || name.trim().isEmpty || !mounted) return;
      setState(() => _working = true);
      await widget.api.post('/admin/exams', body: {
        'action': 'upload',
        'subjectFolderId': subjectFolderId,
        'name': name.trim(),
        'base64': base64Encode(file.bytes!),
      });
      _message('تم رفع ملف الامتحان إلى Drive.');
      await _load();
    } catch (error) {
      _message('تعذر رفع ملف الامتحان: $error', bad: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _askName(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'الاسم'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('متابعة')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _renameExam(Map<String, dynamic> file) async {
    final fileId = _text(file, ['id', 'fileId', 'file_id'], '');
    if (fileId.isEmpty) return;
    final currentName = _text(file, ['name', 'title'], '');
    final name = await _askName('إعادة تسمية ملف الامتحان', currentName);
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.api.post('/admin/exams', body: {'action': 'rename', 'fileId': fileId, 'name': name.trim()});
      _message('تمت إعادة تسمية ملف الامتحان.');
      await _load();
    } catch (error) {
      _message('تعذرت إعادة التسمية: $error', bad: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteExam(Map<String, dynamic> file) async {
    final fileId = _text(file, ['id', 'fileId', 'file_id'], '');
    if (fileId.isEmpty) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف ملف الامتحان؟'),
        content: Text('سيتم حذف «${_text(file, ['name', 'title'], 'الملف')}» من Google Drive نهائيًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف نهائيًا')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.api.post('/admin/exams', body: {'action': 'delete', 'fileId': fileId});
      _message('تم حذف ملف الامتحان.');
      await _load();
    } catch (error) {
      _message('تعذر حذف ملف الامتحان: $error', bad: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _availableTabs;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إدارة إضافية', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('إدارة عناصر السوق والشارات وملفات الامتحانات المتصلة بالـBackend.'),
                ]),
              ),
              IconButton(onPressed: _loading || _working ? null : _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 14),
          if (tabs.length > 1)
            SegmentedButton<String>(
              segments: [
                if (tabs.contains('market')) const ButtonSegment(value: 'market', label: Text('السوق'), icon: Icon(Icons.storefront_outlined)),
                if (tabs.contains('badges')) const ButtonSegment(value: 'badges', label: Text('الشارات'), icon: Icon(Icons.military_tech_outlined)),
                if (tabs.contains('exams')) const ButtonSegment(value: 'exams', label: Text('الامتحانات'), icon: Icon(Icons.picture_as_pdf_outlined)),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) {
                setState(() { _tab = selection.first; _items = []; _examIndex = {}; });
                _load();
              },
            )
          else if (tabs.isNotEmpty)
            Chip(label: Text(tabs.first == 'exams' ? 'ملفات الامتحانات' : tabs.first == 'badges' ? 'الشارات' : 'السوق')),
          const SizedBox(height: 10),
          if (_tab != 'exams')
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: _working ? null : () => _editRecord(),
                icon: const Icon(Icons.add),
                label: Text(_tab == 'market' ? 'إضافة عنصر للسوق' : 'إضافة شارة'),
              ),
            )
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: _working ? null : _syncDrive, icon: const Icon(Icons.sync), label: const Text('مزامنة Drive')),
              OutlinedButton.icon(onPressed: _loading || _working ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحديث الفهرس')),
            ]),
          if (_working) const LinearProgressIndicator(),
          if (_loading && _items.isEmpty && _examIndex.isEmpty)
            const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تعذر تحميل بيانات هذه الوحدة: $_error'),
              Align(alignment: AlignmentDirectional.centerEnd, child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))),
            ]))),
          if (_error == null && !_loading && _tab == 'market') _buildMarketItems(),
          if (_error == null && !_loading && _tab == 'badges') _buildBadges(),
          if (_error == null && !_loading && _tab == 'exams') _buildExams(),
        ],
      ),
    );
  }

  Widget _buildMarketItems() {
    if (_items.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد عناصر سوق مسجلة بعد.')));
    return Column(children: [
      for (final item in _items)
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(_active(item) ? Icons.storefront_outlined : Icons.inventory_2_outlined)),
            title: Text(_text(item, ['title_ar', 'title_en'], 'عنصر دون عنوان'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${_text(item, ['category'], 'بلا تصنيف')} • ${_text(item, ['price_label'], 'السعر غير محدد')}\n${_text(item, ['status'], 'draft') == 'published' ? 'منشور' : 'مسودة'} • ${_active(item) ? 'نشط' : 'متوقف'}', maxLines: 3),
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') _editRecord(item);
                if (action == 'toggle') _toggleActive(item, !_active(item));
                if (action == 'delete') _deleteMarketItem(item);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'toggle', child: Text(_active(item) ? 'إيقاف' : 'تفعيل')),
                const PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _buildBadges() {
    if (_items.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد شارات قابلة للإدارة.')));
    return Column(children: [
      const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('تظل الشارات جزءًا من نظام التقدم؛ يدعم الخادم إضافتها وتعديلها وتعطيلها، ولا يدعم حذفها نهائيًا.'))),
      for (final item in _items)
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(_active(item) ? Icons.military_tech_outlined : Icons.remove_circle_outline)),
            title: Text(_text(item, ['name_ar'], 'شارة دون اسم'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${_text(item, ['rule_type'])} • ${_text(item, ['rule_value'])} • ${_active(item) ? 'نشطة' : 'متوقفة'}'),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') _editRecord(item);
                if (action == 'toggle') _toggleActive(item, !_active(item));
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'toggle', child: Text(_active(item) ? 'تعطيل' : 'تفعيل')),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _buildExams() {
    final subjects = _rows(_examIndex['subjects']);
    if (subjects.isEmpty && _error == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد مواد في فهرس الامتحانات أو أن مكتبة Drive لم تُهيأ بعد. تحقق من إعدادات Drive ثم حدّث الفهرس.')));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_syncRuns.isNotEmpty)
        Card(child: ExpansionTile(
          title: const Text('حالة آخر عمليات مزامنة Drive'),
          children: [for (final run in _syncRuns.take(5)) ListTile(
            dense: true,
            title: Text('${_text(run, ['status'], 'غير معروف')} • ${_text(run, ['started_at', 'created_at'], '')}'),
            subtitle: Text('ملفات: ${_text(run, ['files_seen'], '—')} • محدثة: ${_text(run, ['upserted'], '—')} • أخطاء: ${_text(run, ['error_message'], '—')}'),
          )],
        )),
      for (final subject in subjects)
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(_text(subject, ['subjectName', 'name', 'title'], 'مادة دون اسم'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${_text(subject, ['departmentName', 'department'])} • ${_text(subject, ['semesterName', 'semester'])}'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(onPressed: _working ? null : () => _ensureExamFolder(subject), icon: const Icon(Icons.create_new_folder_outlined), label: const Text('تجهيز مجلد الامتحانات')),
                  FilledButton.icon(onPressed: _working ? null : () => _uploadExam(subject), icon: const Icon(Icons.upload_file_outlined), label: const Text('رفع PDF')),
                ]),
              ),
              const SizedBox(height: 6),
              ..._rows(subject['files']).map((file) => ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(_text(file, ['name', 'title'], 'ملف دون اسم')),
                subtitle: Text('${_text(file, ['modifiedTime', 'modified', 'modified_at'], 'تاريخ غير متاح')} • ${_text(file, ['size', 'sizeBytes'], 'حجم غير متاح')}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'rename') _renameExam(file);
                    if (action == 'delete') _deleteExam(file);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
                    PopupMenuItem(value: 'delete', child: Text('حذف نهائي')),
                  ],
                ),
              )),
              if (_rows(subject['files']).isEmpty)
                const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد ملفات امتحانات لهذه المادة.')),
            ],
          ),
        ),
    ]);
  }
}

class _BadgeEditor extends StatefulWidget {
  const _BadgeEditor({this.item});
  final Map<String, dynamic>? item;
  @override
  State<_BadgeEditor> createState() => _BadgeEditorState();
}

class _BadgeEditorState extends State<_BadgeEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _description, _icon, _value, _sort;
  late String _rule;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? {};
    _name = TextEditingController(text: item['name_ar']?.toString() ?? '');
    _description = TextEditingController(text: item['description_ar']?.toString() ?? '');
    _icon = TextEditingController(text: item['icon_url']?.toString() ?? '');
    _value = TextEditingController(text: item['rule_value']?.toString() ?? '1');
    _sort = TextEditingController(text: item['sort_order']?.toString() ?? '0');
    _rule = const ['xp_total', 'level', 'completed_materials', 'progress_events'].contains(item['rule_type']) ? item['rule_type'].toString() : 'level';
    _active = item['active'] == null || item['active'] == true || item['active'] == 1;
  }

  @override
  void dispose() {
    _name.dispose(); _description.dispose(); _icon.dispose(); _value.dispose(); _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'إضافة شارة' : 'تعديل الشارة'),
    content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الشارة بالعربية *'), validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null),
      TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'الوصف'), minLines: 1, maxLines: 3),
      TextFormField(controller: _icon, decoration: const InputDecoration(labelText: 'رابط الأيقونة HTTPS'), keyboardType: TextInputType.url),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(value: _rule, decoration: const InputDecoration(labelText: 'قاعدة منح الشارة'), items: const [
        DropdownMenuItem(value: 'xp_total', child: Text('إجمالي نقاط XP')),
        DropdownMenuItem(value: 'level', child: Text('المستوى')),
        DropdownMenuItem(value: 'completed_materials', child: Text('المواد المكتملة')),
        DropdownMenuItem(value: 'progress_events', child: Text('أحداث التقدم')),
      ], onChanged: (value) { if (value != null) setState(() => _rule = value); }),
      TextFormField(controller: _value, decoration: const InputDecoration(labelText: 'قيمة القاعدة *'), keyboardType: TextInputType.number, validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'أدخل عددًا صحيحًا موجبًا' : null),
      TextFormField(controller: _sort, decoration: const InputDecoration(labelText: 'ترتيب العرض'), keyboardType: TextInputType.number),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, title: const Text('الشارة نشطة'), onChanged: (value) => setState(() => _active = value)),
    ])))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, <String, dynamic>{
          'name_ar': _name.text.trim(), 'description_ar': _description.text.trim(),
          'icon_url': _icon.text.trim().isEmpty ? null : _icon.text.trim(),
          'rule_type': _rule, 'rule_value': int.parse(_value.text),
          'sort_order': int.tryParse(_sort.text) ?? 0, 'active': _active ? 1 : 0,
        });
      }, child: const Text('حفظ')),
    ],
  );
}

class _MarketItemEditor extends StatefulWidget {
  const _MarketItemEditor({this.item, required this.departments});
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> departments;
  @override
  State<_MarketItemEditor> createState() => _MarketItemEditorState();
}

class _MarketItemEditorState extends State<_MarketItemEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late String _status;
  late String? _department;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? {};
    const fields = ['title_ar','title_en','description_ar','description_en','category','price_label','image_url','contact_url','sort_order'];
    _controllers = {for (final field in fields) field: TextEditingController(text: item[field]?.toString() ?? (field == 'sort_order' ? '0' : ''))};
    _status = item['status']?.toString() == 'published' ? 'published' : 'draft';
    final existingDepartment = item['department_id']?.toString();
    // Preserve a historical/inactive department when editing. Silently replacing
    // it with null would broaden a department-targeted market item to every student.
    _department = existingDepartment;
    _active = item['active'] == null || item['active'] == true || item['active'] == 1;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) { controller.dispose(); }
    super.dispose();
  }

  String? _urlValidator(String? value) {
    final url = value?.trim() ?? '';
    if (url.isNotEmpty && !url.toLowerCase().startsWith('https://')) return 'يجب أن يبدأ الرابط بـ https://';
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'إضافة عنصر للسوق' : 'تعديل عنصر السوق'),
    content: SizedBox(width: 500, child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: _controllers['title_ar'], decoration: const InputDecoration(labelText: 'العنوان بالعربية *'), validator: (v) => v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null),
      TextFormField(controller: _controllers['title_en'], decoration: const InputDecoration(labelText: 'العنوان بالإنجليزية')),
      TextFormField(controller: _controllers['description_ar'], decoration: const InputDecoration(labelText: 'الوصف بالعربية *'), minLines: 2, maxLines: 4, validator: (v) => v == null || v.trim().isEmpty ? 'الوصف مطلوب' : null),
      TextFormField(controller: _controllers['description_en'], decoration: const InputDecoration(labelText: 'الوصف بالإنجليزية'), minLines: 1, maxLines: 3),
      TextFormField(controller: _controllers['category'], decoration: const InputDecoration(labelText: 'التصنيف')),
      TextFormField(controller: _controllers['price_label'], decoration: const InputDecoration(labelText: 'السعر أو وصفه')),
      TextFormField(controller: _controllers['image_url'], decoration: const InputDecoration(labelText: 'رابط الصورة HTTPS'), keyboardType: TextInputType.url, validator: _urlValidator),
      TextFormField(controller: _controllers['contact_url'], decoration: const InputDecoration(labelText: 'رابط التواصل HTTPS'), keyboardType: TextInputType.url, validator: _urlValidator),
      const SizedBox(height: 8),
      DropdownButtonFormField<String?>(
        value: _department,
        decoration: const InputDecoration(labelText: 'القسم المستهدف (اختياري)'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('كل الأقسام')),
          if (_department != null && !widget.departments.any((d) => d['id']?.toString() == _department))
            DropdownMenuItem<String?>(value: _department, child: Text('القسم الحالي غير متاح (${_department!})', overflow: TextOverflow.ellipsis)),
          ...widget.departments.map((d) => DropdownMenuItem<String?>(value: d['id']?.toString(), child: Text((d['name_ar'] ?? d['name'] ?? d['id']).toString(), overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (value) => setState(() => _department = value),
      ),
      DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: 'حالة النشر'), items: const [DropdownMenuItem(value: 'draft', child: Text('مسودة')), DropdownMenuItem(value: 'published', child: Text('منشور'))], onChanged: (value) { if (value != null) setState(() => _status = value); }),
      TextFormField(controller: _controllers['sort_order'], decoration: const InputDecoration(labelText: 'ترتيب العرض'), keyboardType: TextInputType.number),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, title: const Text('عنصر نشط'), onChanged: (value) => setState(() => _active = value)),
    ])))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        String value(String field) => _controllers[field]!.text.trim();
        Navigator.pop(context, <String, dynamic>{
          'title_ar': value('title_ar'), 'title_en': value('title_en'),
          'description_ar': value('description_ar'), 'description_en': value('description_en'),
          'category': value('category'), 'price_label': value('price_label'),
          'image_url': value('image_url').isEmpty ? null : value('image_url'),
          'contact_url': value('contact_url').isEmpty ? null : value('contact_url'),
          'department_id': _department, 'status': _status, 'active': _active ? 1 : 0,
          'sort_order': int.tryParse(value('sort_order')) ?? 0,
        });
      }, child: const Text('حفظ')),
    ],
  );
}

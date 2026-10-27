import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../imports/scanner_import_dialog.dart';

class AcademicPage extends StatefulWidget {
  const AcademicPage({super.key, required this.api, required this.initialTab});
  final ApiService api;
  final int initialTab;

  @override
  State<AcademicPage> createState() => _AcademicPageState();
}

class _AcademicPageState extends State<AcademicPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  final List<Map<String, dynamic>> _subjects = [];
  final List<Map<String, dynamic>> _materials = [];
  final List<Map<String, dynamic>> _schedules = [];
  final List<Map<String, dynamic>> _departments = [];
  final List<Map<String, dynamic>> _semesters = [];
  bool _loading = false;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab == 2 ? 1 : 0);
    _tabs.addListener(() { if (!_tabs.indexIsChanging && mounted) { setState(() {}); } });
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) { return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); }
    if (value is Map && value['data'] is List) { return _rows(value['data']); }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetch(String path) async {
    final result = await widget.api.get(path);
    return _rows(result['data'] ?? result);
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _fetch('/admin/subjects?limit=100'),
        _fetch('/admin/materials?limit=100'),
        _fetch('/admin/schedule?limit=100'),
        _fetch('/departments'),
        _fetch('/semesters'),
      ]);
      if (!mounted) { return; }
      setState(() {
        _replace(_subjects, results[0]);
        _replace(_materials, results[1]);
        _replace(_schedules, results[2]);
        _replace(_departments, results[3]);
        _replace(_semesters, results[4]);
      });
    } catch (e) {
      if (mounted) { setState(() => _error = e.toString()); }
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  void _replace(List<Map<String, dynamic>> target, List<Map<String, dynamic>> values) {
    target..clear()..addAll(values);
  }

  List<Map<String, dynamic>> get _activeRows {
    final rows = switch (_tabs.index) {
      0 => _subjects,
      _ => _schedules,
    };
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) { return rows; }
    return rows.where((row) => row.values.any((value) => value.toString().toLowerCase().contains(q))).toList();
  }

  String get _resource => _tabs.index == 0 ? 'subjects' : 'schedule';
  String get _title => _tabs.index == 0 ? 'المواد الدراسية' : 'الجداول الأكاديمية';

  Future<void> _syncDrive() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('بدء مزامنة الملفات؟'),
      content: const Text('ستضيف المزامنة الشيتات الموجودة في Drive وغير المسجلة في D1 فقط. لن تعدّل أو تحذف السجلات المسجلة.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('بدء المزامنة'))],
    ));
    if (confirmed != true || !mounted) { return; }
    setState(() => _syncing = true);
    try {
      await widget.api.post('/admin/drive/sync');
      if (!mounted) { return; }
      _message('تم إرسال طلب المزامنة بنجاح.');
      await _loadAll();
    } catch (e) {
      if (mounted) { _message('تعذرت المزامنة: $e', error: true); }
    } finally {
      if (mounted) { setState(() => _syncing = false); }
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Theme.of(context).colorScheme.error : null));
  }

  Future<void> _scanSchedule() async {
    if (_departments.isEmpty || _semesters.isEmpty || _subjects.isEmpty) { _message('تعذر تحميل الأقسام أو الفصول أو المواد من الخادم. حدّث البيانات ثم أعد المحاولة.', error: true); return; }
    final result = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => ScannerImportDialog(api: widget.api, type: 'schedule', departments: _departments, semesters: _semesters, subjects: _subjects));
    if (result == true && mounted) { await _loadAll(); }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    if (_tabs.index > 1) { return; }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AcademicEditor(
        resource: _resource,
        initial: item,
        subjects: _subjects,
        departments: _departments,
        semesters: _semesters,
      ),
    );
    if (result == null || !mounted) { return; }
    try {
      final id = item?['id']?.toString();
      if (id == null || id.isEmpty) {
        await widget.api.post('/admin/$_resource', body: result);
      } else {
        await widget.api.patch('/admin/$_resource/$id', body: result);
      }
      _message(id == null ? 'تمت إضافة السجل.' : 'تم حفظ التعديلات.');
      await _loadAll();
    } catch (e) {
      if (mounted) { _message('تعذر حفظ السجل: $e', error: true); }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) { return; }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: Text(_tabs.index == 0 && (item['drive_file_id'] ?? '').toString().isNotEmpty
          ? 'هل تريد حذف «${item['title'] ?? 'الملف'}»؟ قد يؤدي ذلك إلى حذف الملف المرتبط نهائيًا.'
          : _tabs.index == 0
              ? 'هل تريد حذف المادة «${item['name_ar'] ?? item['id']}»؟ قد يحذف الخادم المواد والجداول المرتبطة به، وقد يشمل ذلك ملفات Drive المرتبطة.'
              : 'هل تريد حذف «${item['title'] ?? item['name_ar'] ?? item['id']}»؟ قد يؤثر ذلك على البيانات المرتبطة.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))],
    ));
    if (confirmed != true || !mounted) { return; }
    try {
      await widget.api.delete('/admin/$_resource/$id');
      _message('تم حذف السجل.');
      await _loadAll();
    } catch (e) {
      if (mounted) { _message('تعذر حذف السجل: $e', error: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الإدارة الأكاديمية', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('المقررات والمواد والجداول ومزامنة الملفات', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))])),
          IconButton(tooltip: 'تحديث البيانات', onPressed: _loading ? null : _loadAll, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 18),
        Card(clipBehavior: Clip.antiAlias, child: TabBar(controller: _tabs, isScrollable: false, tabs: const [Tab(icon: Icon(Icons.menu_book_outlined), text: 'المواد الدراسية'), Tab(icon: Icon(Icons.calendar_month_outlined), text: 'الجداول الأكاديمية')])),
        const SizedBox(height: 14),
        if (_tabs.index < 2) TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'ابحث في $_title...', suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close)))),
        if (_tabs.index < 2) const SizedBox(height: 12),
        if (_tabs.index < 2) Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (_tabs.index == 0) OutlinedButton.icon(onPressed: _syncing ? null : _syncDrive, icon: const Icon(Icons.cloud_sync_outlined), label: Text(_syncing ? 'جارٍ المزامنة…' : 'مزامنة الملفات')), if (_tabs.index == 1) OutlinedButton.icon(onPressed: _scanSchedule, icon: const Icon(Icons.document_scanner_outlined), label: const Text('مسح واستيراد جدول')), const SizedBox(width: 10), FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: Text(_tabs.index == 0 ? 'إضافة مادة' : 'إضافة موعد'))]),
        if (_tabs.index < 2) const SizedBox(height: 12),
        if (_loading && _activeRows.isEmpty) const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null && _activeRows.isEmpty) Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 42), const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: _loadAll, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))])))
        else Expanded(child: _activeRows.isEmpty ? Center(child: Text(_loading ? 'جارٍ التحميل...' : (_tabs.index == 0 ? 'لا توجد مواد. أضف مادة جديدة أو استخدم المزامنة.' : 'لا توجد جداول مطابقة.'))) : ListView.separated(itemCount: _activeRows.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) => _rowCard(_activeRows[index], theme))),
      ]),
    ));
  }

  Widget _rowCard(Map<String, dynamic> row, ThemeData theme) {
    final scheduleSubjectName = _tabs.index == 1 ? _lookupName(_subjects, row['subject_id']) : null;
    final title = (_tabs.index == 1 && scheduleSubjectName != null && scheduleSubjectName.isNotEmpty && scheduleSubjectName != '—'
        ? scheduleSubjectName
        : (row['name_ar'] ?? row['title'] ?? row['subject_name'] ?? (_tabs.index == 0 ? 'مقرر دراسي' : 'موعد دراسي'))).toString();
    final subtitle = switch (_tabs.index) {
      0 => 'القسم: ${_lookupName(_departments, row['department_id'])}  •  الفصل: ${_lookupName(_semesters, row['semester_id'])}  •  الشيتات: ${_materials.where((m) => m['subject_id']?.toString() == row['id']?.toString()).length}',
      _ => '${_dayLabel(row['day_of_week'])}  •  ${_displayApiTime(row['start_time'])} – ${_displayApiTime(row['end_time'])}  •  القاعة: ${row['room'] ?? '—'}',
    };
    return Card(child: ListTile(
      leading: CircleAvatar(child: Icon(_tabs.index == 0 ? Icons.menu_book_outlined : Icons.event_note_outlined)),
      title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(subtitle)),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(onSelected: (action) { if (action == 'edit') { _edit(row); } if (action == 'delete') { _delete(row); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]),
      onTap: () { if (_tabs.index == 0) { _openSubject(row); } else _edit(row); },
      dense: false,
    ));
  }

  Future<void> _openSubject(Map<String, dynamic> subject) async {
    final id = subject['id']?.toString();
    if (id == null) { return; }
    await showDialog<void>(context: context, builder: (dialogContext) {
      final sheets = _materials.where((m) => m['subject_id']?.toString() == id).toList();
      return AlertDialog(
        title: Text('ملفات ${subject['name_ar'] ?? 'المادة'}'),
        content: SizedBox(width: 560, child: sheets.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد شيتات مضافة لهذه المادة بعد.')))
          : ListView(shrinkWrap: true, children: sheets.map((sheet) => ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text('${sheet['title'] ?? 'شيت دون عنوان'}'),
              subtitle: Text((sheet['source']?.toString() == 'drive') ? 'ملف متزامن' : 'ملف مضاف يدويًا'),
              trailing: PopupMenuButton<String>(onSelected: (v) { Navigator.pop(dialogContext); if (v == 'edit') { _editMaterial(sheet); } if (v == 'delete') { _deleteMaterial(sheet); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل الشيت')), PopupMenuItem(value: 'delete', child: Text('حذف الشيت'))]),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')), FilledButton.icon(onPressed: () { Navigator.pop(dialogContext); _addSheet(subject); }, icon: const Icon(Icons.add), label: const Text('إضافة شيت PDF'))],
      );
    });
  }

  Future<void> _addSheet(Map<String, dynamic> subject) async {
    final titleController = TextEditingController();
    PlatformFile? selectedFile;
    bool uploading = false;
    String? localError;
    final result = await showDialog<bool>(context: context, barrierDismissible: false, builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('إضافة شيت PDF'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('المادة: ${subject['name_ar'] ?? subject['id']}'),
          const SizedBox(height: 14),
          TextField(controller: titleController, enabled: !uploading, decoration: const InputDecoration(labelText: 'عنوان الشيت', hintText: 'مثال: المحاضرة الأولى')),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: uploading ? null : () async {
              try {
                final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf'], withData: true, allowMultiple: false);
                if (picked == null || picked.files.isEmpty) return;
                final file = picked.files.single;
                if (file.bytes == null) { setDialogState(() => localError = 'تعذر قراءة الملف من الجهاز. حاول اختيار الملف مرة أخرى.'); return; }
                if (file.size > 8 * 1024 * 1024) { setDialogState(() => localError = 'الحد الأقصى لحجم PDF هو 8 ميجابايت.'); return; }
                setDialogState(() { selectedFile = file; localError = null; });
              } catch (e) { setDialogState(() => localError = 'تعذر اختيار الملف: $e'); }
            },
            icon: const Icon(Icons.upload_file),
            label: Text(selectedFile == null ? 'اختيار ملف PDF من الجهاز' : 'تغيير الملف'),
          ),
          if (selectedFile != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
            const Icon(Icons.picture_as_pdf_outlined), const SizedBox(width: 8),
            Expanded(child: Text(selectedFile!.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
            Text('${(selectedFile!.size / 1024 / 1024).toStringAsFixed(1)} MB'),
          ])),
          if (localError != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(localError!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error))),
          if (uploading) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        ]))),
        actions: [
          TextButton(onPressed: uploading ? null : () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: uploading ? null : () async {
              if (titleController.text.trim().isEmpty || selectedFile?.bytes == null) {
                setDialogState(() => localError = 'أدخل عنوان الشيت واختر ملف PDF.');
                return;
              }
              setDialogState(() { uploading = true; localError = null; });
              try {
                await widget.api.post('/admin/materials/upload', body: {
                  'subjectId': subject['id'],
                  'title': titleController.text.trim(),
                  'fileName': selectedFile!.name,
                  'base64': base64Encode(selectedFile!.bytes!),
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (e) {
                setDialogState(() { uploading = false; localError = 'تعذر رفع الشيت: $e'; });
              }
            },
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(uploading ? 'جارٍ الرفع…' : 'رفع وإضافة الشيت'),
          ),
        ],
      ),
    ));
    titleController.dispose();
    if (result == true && mounted) { _message('تم رفع الشيت إلى Drive وتسجيله في D1.'); await _loadAll(); }
  }

  Future<void> _editMaterial(Map<String, dynamic> sheet) async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _AcademicEditor(resource: 'materials', initial: sheet, subjects: _subjects, departments: _departments, semesters: _semesters));
    if (result == null || !mounted) { return; }
    try { await widget.api.patch('/admin/materials/${sheet['id']}', body: result); _message('تم تحديث الشيت.'); await _loadAll(); }
    catch (e) { _message('تعذر تحديث الشيت: $e', error: true); }
  }

  Future<void> _deleteMaterial(Map<String, dynamic> sheet) async {
    try { await widget.api.delete('/admin/materials/${sheet['id']}'); _message('تم حذف الشيت.'); await _loadAll(); }
    catch (e) { _message('تعذر حذف الشيت: $e', error: true); }
  }

  String _lookupName(List<Map<String, dynamic>> rows, dynamic id) {
    for (final row in rows) { if (row['id']?.toString() == id?.toString()) { return '${row['name_ar'] ?? row['name'] ?? row['title'] ?? id}'; } }
    return 'غير محدد';
  }

  String _displayApiTime(dynamic value) {
    final raw = value?.toString() ?? ''; final parts = raw.split(':');
    if (parts.length < 2) { return raw.isEmpty ? 'غير محدد' : raw; }
    final hour = int.tryParse(parts[0]); final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) { return raw; }
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'صباحًا' : 'مساءً'}';
  }

  String _dayLabel(dynamic value) {
    const days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final index = int.tryParse(value?.toString() ?? '');
    return index != null && index >= 0 && index < days.length ? days[index] : 'يوم غير محدد';
  }

}

class _AcademicEditor extends StatefulWidget {
  const _AcademicEditor({required this.resource, required this.subjects, required this.departments, required this.semesters, this.initial});
  final String resource;
  final Map<String, dynamic>? initial;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> semesters;
  @override
  State<_AcademicEditor> createState() => _AcademicEditorState();
}

class _AcademicEditorState extends State<_AcademicEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late String? _subjectId;
  late String? _departmentId;
  late String? _semesterId;
  late int _day;
  late bool _active;
  late bool _pinned;
  TimeOfDay? _startPicker;
  TimeOfDay? _endPicker;
  bool get _isSubject => widget.resource == 'subjects';
  bool get _isMaterial => widget.resource == 'materials';

  @override
  void initState() {
    super.initState();
    final item = widget.initial ?? {};
    final keys = _isSubject
        ? ['name_ar']
        : _isMaterial
            ? ['title', 'description']
            : ['start_time', 'end_time', 'room', 'lecturer'];
    _controllers = {for (final key in keys) key: TextEditingController(text: item[key]?.toString() ?? '')};
    _subjectId = item['subject_id']?.toString();
    _departmentId = item['department_id']?.toString();
    _semesterId = item['semester_id']?.toString();
    _day = int.tryParse(item['day_of_week']?.toString() ?? '') ?? 0;
    _active = item['active'] == null ? true : (item['active'] == 1 || item['active'] == true);
    _pinned = item['pinned'] == 1 || item['pinned'] == true;
    if (!_isSubject && !_isMaterial) {
      _startPicker = _parseTime(item['start_time']?.toString());
      _endPicker = _parseTime(item['end_time']?.toString());
      if (_startPicker != null) { _controllers['start_time']!.text = _displayTime(_startPicker!); }
      if (_endPicker != null) { _controllers['end_time']!.text = _displayTime(_endPicker!); }
    }
  }

  @override
  void dispose() { for (final controller in _controllers.values) { controller.dispose(); } super.dispose(); }

  TimeOfDay? _parseTime(String? value) {
    final parts = (value ?? '').split(':');
    if (parts.length < 2) { return null; }
    final h = int.tryParse(parts[0]); final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) { return null; }
    return TimeOfDay(hour: h, minute: m);
  }
  String _displayTime(TimeOfDay time) { final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod; final m = time.minute.toString().padLeft(2, '0'); return '$h:$m ${time.period == DayPeriod.am ? 'صباحًا' : 'مساءً'}'; }
  String _apiTime(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  Future<void> _pickScheduleTime(String key) async {
    final current = key == 'start_time' ? _startPicker : _endPicker;
    final picked = await showTimePicker(context: context, initialTime: current ?? TimeOfDay.now(), helpText: key == 'start_time' ? 'اختر وقت البداية' : 'اختر وقت النهاية', builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false), child: child!));
    if (picked == null || !mounted) { return; }
    setState(() { if (key == 'start_time') { _startPicker = picked; } else _endPicker = picked; _controllers[key]!.text = _displayTime(picked); });
  }

  String _label(String key) => switch (key) {
    'name_ar' => 'اسم المادة بالعربية',
    'title' => 'عنوان الملف', 'description' => 'وصف المادة', 'start_time' => 'وقت البداية' ,
    'end_time' => 'وقت النهاية' , 'room' => 'القاعة', 'lecturer' => 'المحاضر', _ => key,
  };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) { return; }
    final result = <String, dynamic>{};
    // Hidden administrative flags are preserved automatically; new records default to active.
    result['active'] = widget.initial == null ? 1 : (_active ? 1 : 0);
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) { continue; }
      if (entry.key == 'sort_order') { result[entry.key] = int.tryParse(value) ?? 0; } else { result[entry.key] = value; }
    }
    if (!_isSubject && !_isMaterial) {
      if (_startPicker == null || _endPicker == null) { _showError('اختر وقت البداية والنهاية من أداة الوقت.'); return; }
      result['start_time'] = _apiTime(_startPicker!);
      result['end_time'] = _apiTime(_endPicker!);
    }
    if (_isSubject) {
      if (_departmentId == null || _semesterId == null) { _showError('اختر القسم والفصل الدراسي.'); return; }
      result.addAll({'department_id': _departmentId, 'semester_id': _semesterId});
    } else if (_isMaterial) {
      if (_subjectId == null) { _showError('اختر المقرر المرتبط بالمادة.'); return; }
      result['subject_id'] = _subjectId;
      result['pinned'] = widget.initial == null ? 0 : (_pinned ? 1 : 0);
      result['source'] = widget.initial?['source'] ?? 'manual';
    } else {
      if (_subjectId == null || _departmentId == null || _semesterId == null) { _showError('اختر المقرر والقسم والفصل.'); return; }
      result.addAll({'subject_id': _subjectId, 'department_id': _departmentId, 'semester_id': _semesterId, 'day_of_week': _day});
    }
    Navigator.pop(context, result);
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'إضافة ${_isSubject ? 'مقرر' : _isMaterial ? 'مادة دراسية' : 'موعد دراسي'}' : 'تعديل السجل'),
    content: SizedBox(width: 480, child: SingleChildScrollView(child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (_isSubject || !_isMaterial) _dropdown('القسم الأكاديمي', _departmentId, widget.departments, (v) => setState(() { _departmentId = v; _subjectId = null; }), 'name_ar'),
      if (_isSubject || !_isMaterial) _dropdown('الفصل الدراسي', _semesterId, widget.semesters, (v) => setState(() { _semesterId = v; _subjectId = null; }), 'name_ar'),
      if (_isMaterial || !_isSubject) _dropdown('المقرر', _subjectId, widget.subjects.where((s) => (_departmentId == null || s['department_id']?.toString() == _departmentId) && (_semesterId == null || s['semester_id']?.toString() == _semesterId)).toList(), (v) => setState(() => _subjectId = v), 'name_ar'),
      if (!_isSubject && !_isMaterial) DropdownButtonFormField<int>(initialValue: _day, decoration: const InputDecoration(labelText: 'اليوم'), items: const [DropdownMenuItem(value: 0, child: Text('الأحد')), DropdownMenuItem(value: 1, child: Text('الاثنين')), DropdownMenuItem(value: 2, child: Text('الثلاثاء')), DropdownMenuItem(value: 3, child: Text('الأربعاء')), DropdownMenuItem(value: 4, child: Text('الخميس')), DropdownMenuItem(value: 5, child: Text('الجمعة')), DropdownMenuItem(value: 6, child: Text('السبت'))], onChanged: (v) => setState(() => _day = v ?? 0)),
      ..._controllers.entries.map((entry) => Padding(padding: const EdgeInsets.only(top: 10), child: TextFormField(controller: entry.value, readOnly: !_isSubject && !_isMaterial && (entry.key == 'start_time' || entry.key == 'end_time'), onTap: !_isSubject && !_isMaterial && (entry.key == 'start_time' || entry.key == 'end_time') ? () => _pickScheduleTime(entry.key) : null, decoration: InputDecoration(labelText: _label(entry.key), suffixIcon: !_isSubject && !_isMaterial && (entry.key == 'start_time' || entry.key == 'end_time') ? const Icon(Icons.access_time) : null), keyboardType: entry.key == 'sort_order' ? TextInputType.number : TextInputType.text, validator: (v) => entry.key == 'title' && (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : entry.key == 'name_ar' && (v == null || v.trim().isEmpty) ? 'اسم المادة مطلوب' : null))),

    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: _save, child: const Text('حفظ'))],
  );

  Widget _dropdown(String label, String? value, List<Map<String, dynamic>> options, ValueChanged<String?> onChanged, String titleKey) {
    final validValue = options.any((row) => row['id']?.toString() == value) ? value : null;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: DropdownButtonFormField<String>(
      initialValue: validValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.map((row) => DropdownMenuItem(value: row['id']?.toString(), child: Text('${row[titleKey] ?? row['name'] ?? 'بدون اسم'}', overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    ));
  }
}

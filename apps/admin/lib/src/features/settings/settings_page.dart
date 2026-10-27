import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.api});
  final ApiService api;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }

  List<Map<String, dynamic>> _rows(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.get('/admin/settings');
      if (mounted) { setState(() => _items = _rows(result['data']).where((item) { final key = item['key']?.toString() ?? ''; return key.startsWith('public.') || key == 'Logo'; }).toList()); }
    } catch (e) { if (mounted) { setState(() => _error = e.toString()); } }
    finally { if (mounted) { setState(() => _loading = false); } }
  }

  dynamic _parseStored(dynamic raw) {
    if (raw is! String) { return raw; }
    try { return jsonDecode(raw); } catch (_) { return raw; }
  }

  Future<void> _edit(Map<String, dynamic>? item) async {
    final keyController = TextEditingController(text: item?['key']?.toString() ?? '');
    final valueController = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(_parseStored(item?['value_json'])));
    final formKey = GlobalKey<FormState>();
    final isNew = item == null;
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => AlertDialog(
      title: Text(isNew ? 'إضافة إعداد' : 'تعديل الإعداد'),
      content: SizedBox(width: 560, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: keyController, enabled: isNew, decoration: const InputDecoration(labelText: 'مفتاح الإعداد'), validator: (v) { final key = v?.trim() ?? ''; if (key.isEmpty) { return 'المفتاح مطلوب'; } if (key.length > 128) { return 'الحد الأقصى 128 حرفًا'; } if (!(key.startsWith('public.') || key == 'Logo')) { return 'يسمح فقط بمفاتيح public.* أو Logo'; } return null; }),
        const SizedBox(height: 12),
        TextFormField(controller: valueController, minLines: 5, maxLines: 12, decoration: const InputDecoration(labelText: 'القيمة بصيغة JSON', alignLabelWithHint: true, hintText: '{\n  "enabled": true\n}'), validator: (v) { try { jsonDecode(v ?? ''); return null; } catch (_) { return 'أدخل JSON صحيحًا'; } }),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: () { if (!formKey.currentState!.validate()) { return; } Navigator.pop(context, {'key': keyController.text.trim(), 'value': jsonDecode(valueController.text)}); }, child: const Text('حفظ')),
      ],
    ));
    keyController.dispose(); valueController.dispose();
    if (result == null || !mounted) { return; }
    try {
      await widget.api.put('/admin/settings/${Uri.encodeComponent(result['key'] as String)}', body: result);
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعداد.')));
      await _load();
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الإعداد: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(20), children: [
    Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('إعدادات النظام', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 5), const Text('إدارة إعدادات العرض العامة public.* والشعار فقط. غيّر القيم عند معرفة أثرها على الموقع والتطبيق.') ])), IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh))]),
    const SizedBox(height: 12),
    const Card(child: Padding(padding: EdgeInsets.all(12), child: Row(children: [Icon(Icons.warning_amber_outlined), SizedBox(width: 10), Expanded(child: Text('القيم تُحفظ بصيغة JSON. تغيير مفتاح يستخدمه الموقع قد يؤثر على واجهته أيضًا؛ احتفظ بنسخة من القيمة السابقة قبل تعديل إعداد مهم.'))]))),
    const SizedBox(height: 12),
    Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('إضافة إعداد'))),
    if (_loading && _items.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
    if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('تعذر تحميل الإعدادات: $_error'))),
    if (!_loading && _error == null && _items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد إعدادات مسجلة.'))),
    for (final item in _items) Card(child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.tune_outlined)),
      title: Text(_settingLabel(item['key']?.toString() ?? 'مفتاح غير معروف'), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('المفتاح التقني: ${item['key'] ?? '—'}', textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), Text(_compactValue(item['value_json']), maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr)])),
      trailing: IconButton(tooltip: 'تعديل', onPressed: () => _edit(item), icon: const Icon(Icons.edit_outlined)),
    )),
  ]));

  String _settingLabel(String key) => switch (key) {
    'Logo' => 'شعار النظام',
    'public.app_name' => 'اسم التطبيق العام',
    'public.app_description' => 'وصف التطبيق',
    'public.support_email' => 'بريد الدعم الفني',
    'public.maintenance_mode' => 'وضع الصيانة',
    'public.maintenance_message' => 'رسالة الصيانة',
    _ => key.startsWith('public.') ? key.substring(7).replaceAll('_', ' ') : key,
  };

  String _compactValue(dynamic value) {
    final parsed = _parseStored(value);
    try { return const JsonEncoder.withIndent('  ').convert(parsed); } catch (_) { return parsed.toString(); }
  }
}

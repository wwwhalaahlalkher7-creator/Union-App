import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../session_store.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api, required this.session, required this.onSignOut});
  final ApiService api;
  final AdminSession session;
  final VoidCallback onSignOut;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hideCurrent = true;
  bool _hideNext = true;
  late String _displayName;
  String _email = '';
  @override
  void initState() { super.initState(); _displayName = widget.session.displayName; _loadProfile(); }
  Future<void> _loadProfile() async { try { final r = await widget.api.get('/auth/staff/profile'); final data = r['data'] is Map ? Map<String,dynamic>.from(r['data']) : r; if (mounted) { setState(() { _displayName = (data['displayName'] ?? data['display_name'] ?? _displayName).toString(); _email = (data['email'] ?? '').toString(); }); } } catch (_) { /* Profile endpoint can be added with the backend follow-up. */ } }

  @override
  void dispose() { _current.dispose(); _next.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _displayName);
    final email = TextEditingController(text: _email);
    final form = GlobalKey<FormState>();
    final data = await showDialog<Map<String,String>>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('تعديل بيانات المشرف'),
      content: SizedBox(width: 440, child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المشرف *'), validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null),
        const SizedBox(height: 12),
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), validator: (v) => v != null && v.trim().isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? 'البريد الإلكتروني غير صالح' : null),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')), FilledButton(onPressed: () { if (form.currentState!.validate()) { Navigator.pop(dialogContext, {'displayName': name.text.trim(), 'email': email.text.trim()}); } }, child: const Text('حفظ'))],
    ));
    name.dispose(); email.dispose();
    if (data == null || !mounted) { return; }
    try {
      await widget.api.patch('/auth/staff/profile', body: data);
      if (!mounted) { return; }
      setState(() { _displayName = data['displayName']!; _email = data['email']!; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات المشرف.')));
    } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث البيانات: $e'))); } }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) { return; }
    setState(() => _busy = true);
    try {
      await widget.api.post('/auth/staff/change-password', body: {
        'currentPassword': _current.text,
        'newPassword': _next.text,
      });
      _current.clear(); _next.clear(); _confirm.clear();
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور. أُبطلت الجلسات الأخرى لهذا الحساب.')));
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تغيير كلمة المرور: $e'))); }
    } finally { if (mounted) { setState(() => _busy = false); } }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    Text('حسابي', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('بيانات الجلسة الحالية وأمان حساب الإدارة.'),
    const SizedBox(height: 18),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'تعديل بيانات المشرف',
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          Row(children: [
            CircleAvatar(radius: 28, child: Text(_displayName.isEmpty ? '؟' : _displayName.substring(0, 1))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              if (_email.isNotEmpty) ...[const SizedBox(height: 4), Text(_email)],
              const SizedBox(height: 4), Text('الدور: ${_roleLabel(widget.session.role)}'),
              const SizedBox(height: 4),
              const Text('رموز الجلسة محفوظة باستخدام التخزين الآمن على الجهاز.'),
            ])),
          ]),
        ]),
      ),
    ),
    const SizedBox(height: 14),
    Card(child: Padding(padding: const EdgeInsets.all(18), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('تغيير كلمة المرور', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6), const Text('يجب أن تكون كلمة المرور الجديدة من 8 إلى 256 حرفًا، وألا تطابق الحالية.'),
      const SizedBox(height: 16),
      TextFormField(controller: _current, obscureText: _hideCurrent, decoration: InputDecoration(labelText: 'كلمة المرور الحالية', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _hideCurrent = !_hideCurrent), icon: Icon(_hideCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.isEmpty ? 'أدخل كلمة المرور الحالية' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _next, obscureText: _hideNext, decoration: InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: const Icon(Icons.password_outlined), suffixIcon: IconButton(onPressed: () => setState(() => _hideNext = !_hideNext), icon: Icon(_hideNext ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.length < 8 || v.length > 256 ? 'استخدم 8 إلى 256 حرفًا' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _confirm, obscureText: _hideNext, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة', prefixIcon: Icon(Icons.check_circle_outline)), validator: (v) => v != _next.text ? 'كلمتا المرور غير متطابقتين' : null),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _busy ? null : _changePassword, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.key_outlined), label: const Text('حفظ كلمة المرور')),
    ])))),
    const SizedBox(height: 14),
    OutlinedButton.icon(onPressed: widget.onSignOut, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج من الحساب')),
  ]);

  String _roleLabel(String role) => switch (role) {
    'super_admin' => 'مدير النظام',
    'content_manager' => 'مدير المحتوى',
    'academic_manager' => 'مدير الشؤون الأكاديمية',
    _ => role.isEmpty ? 'غير محدد' : role,
  };
}

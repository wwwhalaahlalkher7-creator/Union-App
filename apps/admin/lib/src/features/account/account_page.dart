import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../session_store.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api, required this.session, required this.onSignOut, this.onDisplayNameChanged});
  final ApiService api;
  final AdminSession session;
  final VoidCallback onSignOut;
  final ValueChanged<String>? onDisplayNameChanged;

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
  Future<void> _loadProfile() async {
    try {
      final data = await widget.api.get('/auth/staff/me');
      if (mounted) {
        setState(() {
          _displayName = (data['display_name'] ?? widget.session.displayName).toString();
          _email = (data['email'] ?? '').toString();
        });
      }
    } catch (_) { /* Keep the authenticated session values when profile details cannot be loaded. */ }
  }

  @override
  void dispose() { _current.dispose(); _next.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _displayName);
    final email = TextEditingController(text: _email);
    final form = GlobalKey<FormState>();
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل بيانات الحساب'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: name,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'اسم الموظف *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'الاسم مطلوب'
                    : value.trim().length > 120 ? 'الاسم طويل جدًا' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني *'),
                validator: (value) => value == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
                    ? 'أدخل بريدًا إلكترونيًا صحيحًا'
                    : null,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, {
                  'displayName': name.text.trim(),
                  'email': email.text.trim(),
                });
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    if (data == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.api.patch('/auth/staff/profile', body: data);
      if (!mounted) return;
      final updatedName = (result['display_name'] ?? data['displayName']!).toString();
      final updatedEmail = (result['email'] ?? data['email']!).toString();
      setState(() {
        _displayName = updatedName;
        _email = updatedEmail;
      });
      widget.onDisplayNameChanged?.call(updatedName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث بيانات الحساب بنجاح.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث البيانات: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    const Text('إدارة بيانات حسابك، وكلمة المرور، والجلسة الآمنة.'),
    const SizedBox(height: 18),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Spacer(),
            IconButton(tooltip: 'تعديل بيانات الحساب', onPressed: _busy ? null : _editProfile, icon: const Icon(Icons.edit_outlined)),
          ]),
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

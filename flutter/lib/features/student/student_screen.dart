import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/auth_storage.dart';
import '../../data/models/student_profile.dart';
import '../../data/repositories/student_repository.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();

  AuthStorage? _storage;
  ApiClient? _client;
  StudentRepository? _repo;
  bool _loading = true;
  String? _error;
  StudentProfile? _profile;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _storage = AuthStorage(prefs);
    _client = ApiClient(baseUrl: AppConstants.apiBaseUrl, authStorage: _storage);
    _repo = StudentRepository(_client!);
    if (_storage!.isLoggedIn) await _loadProfile();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final repository = _repo;
      if (repository == null) return;
      final profile = await repository.profile();
      final stats = await repository.stats();
      if (mounted) {
        setState(() {
          _profile = profile;
          _stats = stats;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _login() async {
    final client = _client;
    final storage = _storage;
    if (client == null || storage == null || _id.text.trim().isEmpty || _password.text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final json = await client.postJson(
        '/api/v1/auth/login',
        body: {
          'studentNumber': _id.text.trim(),
          'password': _password.text,
        },
      );
      final data = json['data'];
      if (data is Map) await storage.saveSession(Map<String, dynamic>.from(data));
      await _loadProfile();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _client?.postJson('/api/v1/auth/logout');
    } catch (_) {}
    await _storage?.clear();
    if (mounted) setState(() { _profile = null; _stats = {}; });
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    _client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _profile == null ? _loginView(context) : _profileView(context);

  Widget _loginView(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('حساب الطالب')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(Icons.school_rounded, size: 34, color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 14),
                const Text('مساحتك الدراسية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('سجّل الدخول للوصول إلى المواد والجدول والتقدم والشارات.', textAlign: TextAlign.center),
                const SizedBox(height: 22),
                TextField(
                  controller: _id,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الرقم الجامعي', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور / رمز التحقق', prefixIcon: Icon(Icons.lock_outline)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 16),
                AppButton(label: 'تسجيل الدخول', icon: Icons.login_rounded, onPressed: _loading ? null : _login),
                const SizedBox(height: 8),
                TextButton(onPressed: () => context.pop(), child: const Text('العودة كزائر')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileView(BuildContext context) {
    final profile = _profile!;
    final xp = _stats['xp_total'] ?? _stats['xpTotal'] ?? 0;
    final level = _stats['level'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفي الدراسي'),
        actions: [IconButton(tooltip: 'تسجيل الخروج', onPressed: _logout, icon: const Icon(Icons.logout_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(radius: 30, child: Text(profile.name.isEmpty ? 'ط' : profile.name.characters.first)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name.isEmpty ? 'طالب' : profile.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('الرقم الجامعي: ${profile.number}'),
                        if (profile.departmentName != null) Text(profile.departmentName!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _stat('المستوى', '$level', Icons.trending_up_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _stat('XP', '$xp', Icons.bolt_rounded)),
              ],
            ),
            const SizedBox(height: 22),
            AppSection(
              title: 'لوحتك الدراسية',
              child: Column(
                children: [
                  _link('المواد الدراسية', 'مواد القسم والفصل المرتبط بحسابك', Icons.menu_book_rounded, '/materials'),
                  _link('الجدول الدراسي', 'جدول قسمك وفصلك الحالي', Icons.calendar_month_rounded, '/schedule'),
                  _link('تقدمي الدراسي', 'تابع تقدمك في الملفات', Icons.insights_rounded, '/progress'),
                  _link('XP والمستوى', 'نقاطك ومراحل تقدمك', Icons.bolt_rounded, '/xp'),
                  _link('الشارات', 'إنجازاتك الدراسية', Icons.emoji_events_rounded, '/badges'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _link(String title, String subtitle, IconData icon, String route) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => context.go(route),
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

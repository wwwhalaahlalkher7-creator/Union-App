import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/student_profile.dart';
import '../../data/repositories/student_repository.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_section.dart';
import '../../shared/widgets/list_skeleton.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});
  @override State<StudentScreen> createState() => _StudentScreenState();
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
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storage = AuthStorage(prefs);
      final client = ApiClient(baseUrl: AppConstants.apiBaseUrl, authStorage: storage);
      if (!mounted) { client.dispose(); return; }
      _storage = storage;
      _client = client;
      _repo = StudentRepository(client);
      if (storage.isLoggedIn) await _loadProfile();
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    final repository = _repo;
    if (repository == null) return;
    try {
      final profile = await repository.profile();
      final stats = await repository.stats();
      if (mounted) setState(() { _profile = profile; _stats = stats; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  Future<void> _login() async {
    final client = _client;
    final storage = _storage;
    if (client == null || storage == null || _id.text.trim().isEmpty || _password.text.isEmpty) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).t('loginFieldsRequired'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final json = await client.postJson('/api/v1/auth/login', body: {'studentNumber': _id.text.trim(), 'password': _password.text});
      final data = json['data'];
      if (data is! Map) throw ApiException(AppLocalizations.of(context).t('loginFailed'));
      await storage.saveSession(Map<String, dynamic>.from(data));
      await _loadProfile();
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : AppLocalizations.of(context).t('loginFailed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try { await _client?.postJson('/api/v1/auth/logout'); } catch (_) {}
    await _storage?.clear();
    if (mounted) setState(() { _profile = null; _stats = {}; });
  }

  @override
  void dispose() { _id.dispose(); _password.dispose(); _client?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading && _profile == null) return Scaffold(appBar: AppBar(title: Text(AppLocalizations.of(context).t('studentAccount'))), body: const ListSkeleton(count: 6));
    return _profile == null ? _loginView(context) : _profileView(context);
  }

  Widget _loginView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('studentAccount'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              Container(width: 74, height: 74, decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.school_rounded, size: 38, color: cs.onPrimaryContainer)),
              const SizedBox(height: 14),
              Text(l10n.t('studySpace'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(l10n.t('signInToStudy'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 22),
              TextField(controller: _id, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.t('studentNumber'), prefixIcon: const Icon(Icons.badge_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: l10n.t('passwordOrCode'), prefixIcon: const Icon(Icons.lock_outline))),
              if (_error != null) ...[const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error))],
              const SizedBox(height: 16),
              AppButton(label: l10n.t('signIn'), icon: Icons.login_rounded, onPressed: _loading ? null : _login),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.pop(), child: Text(l10n.t('continueAsGuest'))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _profileView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = _profile!;
    final xp = _number('xp_total', fallback: _number('xpTotal'));
    final level = _number('level', fallback: 1);
    final started = _number('files_started', fallback: _number('started'));
    final completed = _number('files_completed', fallback: _number('completed'));
    final badges = _number('badges', fallback: _number('badges_earned'));
    final xpNext = _number('next_level_xp', fallback: 100);
    final levelXp = _number('level_xp');
    final xpRatio = xpNext <= 0 ? 0.0 : (levelXp / xpNext).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('studentProfile')), actions: [IconButton(tooltip: l10n.t('signOut'), onPressed: _logout, icon: const Icon(Icons.logout_rounded))]),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 38),
          children: [
            _ProfileHero(profile: profile, level: level, xp: xp, xpRatio: xpRatio, xpNext: xpNext, levelXp: levelXp),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) {
              final cards = [
                _MiniStat(value: '$started', label: l10n.t('filesStarted'), icon: Icons.menu_book_rounded),
                _MiniStat(value: '$completed', label: l10n.t('filesCompleted'), icon: Icons.check_circle_outline_rounded),
                _MiniStat(value: '$badges', label: l10n.t('achievements'), icon: Icons.emoji_events_rounded),
              ];
              final width = (constraints.maxWidth - 16) / 3;
              if (constraints.maxWidth >= 420) return Row(children: [for (var i = 0; i < cards.length; i++) Expanded(child: Padding(padding: EdgeInsetsDirectional.only(end: i == 2 ? 0 : 8), child: cards[i]))]);
              return Wrap(spacing: 8, runSpacing: 8, children: cards.map((card) => SizedBox(width: width, child: card)).toList());
            }),
            const SizedBox(height: 22),
            AppSection(title: l10n.t('studyDashboard'), child: Column(children: [
              _link(l10n.t('materials'), l10n.t('materialsStudentSubtitle'), Icons.menu_book_rounded, '/materials'),
              _link(l10n.t('schedule'), l10n.t('scheduleStudentSubtitle'), Icons.calendar_month_rounded, '/schedule'),
              _link(l10n.t('studyProgress'), l10n.t('progressStudentSubtitle'), Icons.insights_rounded, '/progress'),
              _link(l10n.t('xpLevel'), l10n.t('studyProgressSubtitle'), Icons.bolt_rounded, '/xp'),
              _link(l10n.t('achievements'), l10n.t('badgesStudentSubtitle'), Icons.emoji_events_rounded, '/badges'),
            ])),
          ],
        ),
      ),
    );
  }

  int _number(String key, {int fallback = 0}) => int.tryParse('${_stats[key] ?? fallback}') ?? fallback;

  Widget _link(String title, String subtitle, IconData icon, String route) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(onTap: () => context.go(route), padding: const EdgeInsets.all(13), child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])),
      const Icon(Icons.chevron_right_rounded),
    ])),
  );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.level, required this.xp, required this.xpRatio, required this.xpNext, required this.levelXp});
  final StudentProfile profile;
  final int level, xp, xpNext, levelXp;
  final double xpRatio;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [cs.primary, AppColors.navy]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .16), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(radius: 31, backgroundColor: Colors.white.withValues(alpha: .16), child: Text(profile.name.isEmpty ? l10n.t('studentFallback').characters.first : profile.name.characters.first, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile.name.isEmpty ? l10n.t('studentFallback') : profile.name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(profile.departmentName ?? l10n.t('student'), style: TextStyle(color: Colors.white.withValues(alpha: .82))), Text(profile.number, style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 12))]))]),
        const SizedBox(height: 20),
        Row(children: [Text(l10n.t('levelValue', {'level': '$level'}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const Spacer(), Text(l10n.t('xpValue', {'value': '$xp'}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 9),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: xpRatio, minHeight: 9, backgroundColor: Colors.white.withValues(alpha: .18), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))),
        const SizedBox(height: 7),
        Text(l10n.t('xpNextLevel', {'current': '$levelXp', 'next': '$xpNext'}), style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 12)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label, required this.icon});
  final String value, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppCard(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 7), child: Column(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)]));
}

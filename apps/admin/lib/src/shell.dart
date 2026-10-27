import 'package:flutter/material.dart';
import 'api_service.dart';
import 'session_store.dart';
import 'admin_permissions.dart';
import 'admin_section.dart';
import 'design_system/trinex_theme.dart';
import 'features/moderation/feedback_reports_page.dart';
import 'features/security/eino_monitor_page.dart';
import 'features/content/content_page.dart';
import 'features/academic/academic_page.dart';
import 'features/users/users_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/security/security_page.dart';
import 'features/account/account_page.dart';
import 'features/analytics/analytics_page.dart';
import 'features/settings/settings_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.api, required this.sessionStore});
  final ApiService api;
  final SessionStore sessionStore;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSession? _session;
  bool _checkingSession = true;
  AdminSection _section = AdminSection.overview;

  List<AdminSection> _visibleSections(String role) =>
      AdminSection.values.where((section) => AdminPermissions.canSee(role, section)).toList();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await widget.sessionStore.readIncludingExpired();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _checkingSession = false;
    });
  }

  Future<void> _signOut() async {
    await widget.api.logout();
    if (!mounted) {
      return;
    }
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_session == null) {
      return LoginScreen(
        api: widget.api,
        onLoggedIn: (session) => setState(() => _session = session),
      );
    }

    final visibleSections = _visibleSections(_session!.role);
    if (!visibleSections.contains(_section)) { _section = AdminSection.overview; }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isCompact = constraints.maxWidth < 600;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(width: 270, child: _NavigationRailPanel(
                  selected: _section,
                  sections: visibleSections,
                  onSelect: (section) => setState(() => _section = section),
                  session: _session!,
                  onSignOut: _signOut,
                )),
                const VerticalDivider(width: 1),
                Expanded(child: _buildPage()),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_section.title),
            actions: [
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          drawer: Drawer(
            child: SafeArea(
              child: _NavigationRailPanel(
                selected: _section,
                sections: visibleSections,
                onSelect: (section) {
                  setState(() => _section = section);
                  Navigator.of(context).pop();
                },
                session: _session!,
                onSignOut: _signOut,
              ),
            ),
          ),
          body: _buildPage(),
          bottomNavigationBar: isCompact ? _CompactBottomBar(
            selected: _section,
            sections: _compactSections(visibleSections),
            onSelect: (section) => setState(() => _section = section),
          ) : null,
        );
      },
    );
  }

  Widget _buildPage() {
    switch (_section) {
      case AdminSection.analytics:
        return AnalyticsPage(api: widget.api);
      case AdminSection.overview:
        return DashboardPage(
          api: widget.api,
          session: _session!,
          onNavigate: (section) => setState(() => _section = section),
          visibleSections: _visibleSections(_session!.role),
        );
      case AdminSection.feedbackReports:
        return FeedbackReportsPage(api: widget.api);
      case AdminSection.eino:
        return EinoMonitorPage(api: widget.api);
      case AdminSection.notifications:
        return NotificationsPage(api: widget.api);
      case AdminSection.content:
        return ContentPage(api: widget.api, role: _session!.role);
      case AdminSection.students:
        return StudentsPage(api: widget.api);
      case AdminSection.staff:
        return StaffPage(api: widget.api, currentRole: _session!.role);
      case AdminSection.materials:
        return AcademicPage(api: widget.api, initialTab: 1);
      case AdminSection.schedule:
        return AcademicPage(api: widget.api, initialTab: 2);
      case AdminSection.security:
        return SecurityPage(api: widget.api);
      case AdminSection.settings:
        return SettingsPage(api: widget.api);
      case AdminSection.account:
        return AccountPage(api: widget.api, session: _session!, onSignOut: _signOut);
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onLoggedIn});
  final ApiService api;
  final ValueChanged<AdminSession> onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) { return; }
    setState(() { _busy = true; _error = null; });
    try {
      final session = await widget.api.login(_userController.text, _passwordController.text);
      if (mounted) {
        widget.onLoggedIn(session);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 68, height: 68,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.admin_panel_settings_outlined,
                          size: 36, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 20),
                      Text('TRINEX Admin',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('تسجيل دخول المشرفين والموظفين'),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _userController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(labelText: 'اسم المستخدم أو المعرّف'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'أدخل اسم المستخدم' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'أدخل كلمة المرور' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: _busy
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('تسجيل الدخول'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'تُحفظ الجلسة في التخزين الآمن للجهاز. الصلاحيات النهائية يفرضها الخادم.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.api,
    required this.session,
    required this.onNavigate,
    required this.visibleSections,
  });

  final ApiService api;
  final AdminSession session;
  final ValueChanged<AdminSection> onNavigate;
  final List<AdminSection> visibleSections;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  bool? _apiHealthy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([widget.api.getDashboardOverview(), widget.api.checkHealth()]);
      final stats = results[0] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _stats = stats;
          _apiHealthy = results[1] as bool;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int _number(String key) => int.tryParse(_stats?[key]?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.now();
    final dateLabel = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final stats = <_StatData>[
      _StatData('إجمالي الطلاب', _number('students'), Icons.school_outlined, const Color(0xFF3859D9)),
      _StatData('الطلاب النشطون', _number('activeStudents'), Icons.verified_user_outlined, TrinexColors.success),
      _StatData('الموظفون', _number('staff'), Icons.badge_outlined, const Color(0xFF7B54C6)),
      _StatData('الموظفون النشطون', _number('activeStaff'), Icons.groups_2_outlined, const Color(0xFF0C8B9A)),
      _StatData('المواد الدراسية', _number('materials'), Icons.menu_book_outlined, const Color(0xFFAF6A18)),
      _StatData('الأخبار', _number('news'), Icons.article_outlined, const Color(0xFFCA5573)),
      _StatData('الإعلانات', _number('announcements'), Icons.campaign_outlined, const Color(0xFF397A63)),
      _StatData('التعليقات الظاهرة', _number('visibleComments'), Icons.forum_outlined, const Color(0xFF5A72A7)),
    ];
    final quickActions = <_QuickAction>[
      const _QuickAction(AdminSection.content, 'إدارة المحتوى', 'الأخبار والإعلانات والفعاليات', Icons.article_outlined),
      const _QuickAction(AdminSection.materials, 'المواد الدراسية', 'المواد والملفات الأكاديمية', Icons.menu_book_outlined),
      const _QuickAction(AdminSection.staff, 'إدارة الموظفين', 'الحسابات والأدوار الإدارية', Icons.manage_accounts_outlined),
      const _QuickAction(AdminSection.security, 'الأمان والتدقيق', 'أحداث الدخول وسجل العمليات', Icons.shield_outlined),
      const _QuickAction(AdminSection.analytics, 'التحليلات والاستخدام', 'نشاط التطبيق والموقع والأقسام', Icons.query_stats_outlined),
      const _QuickAction(AdminSection.eino, 'مراقبة إينو', 'الأداء والأخطاء ومزودو الخدمة', Icons.monitor_heart_outlined),
      const _QuickAction(AdminSection.feedbackReports, 'المقترحات والبلاغات', 'رسائل الطلاب ومتابعة المقترحات والمشكلات', Icons.feedback_outlined),
      const _QuickAction(AdminSection.schedule, 'الجداول الأكاديمية', 'الجداول والمواعيد', Icons.calendar_month_outlined),
    ].where((item) => widget.visibleSections.contains(item.section)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 14,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مركز التحكم', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 29)),
                    const SizedBox(height: 8),
                    Text('مرحبًا ${widget.session.displayName}، إليك ملخص المنصة اليوم.', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: TrinexColors.muted),
                      const SizedBox(width: 7),
                      Text(dateLabel, style: theme.textTheme.bodySmall?.copyWith(color: TrinexColors.muted)),
                      const SizedBox(width: 12),
                      Container(width: 5, height: 5, decoration: const BoxDecoration(color: TrinexColors.success, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(AdminPermissions.roleLabel(widget.session.role), style: theme.textTheme.bodySmall?.copyWith(color: TrinexColors.muted)),
                    ]),
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_apiHealthy == true ? Icons.cloud_done_outlined : _apiHealthy == false ? Icons.cloud_off_outlined : Icons.cloud_queue_outlined, size: 16, color: _apiHealthy == true ? TrinexColors.success : _apiHealthy == false ? theme.colorScheme.error : TrinexColors.muted),
                      const SizedBox(width: 6),
                      Text(_apiHealthy == true ? 'واجهة API متصلة' : _apiHealthy == false ? 'واجهة API غير متاحة' : 'جارٍ فحص واجهة API', style: theme.textTheme.bodySmall?.copyWith(color: _apiHealthy == true ? TrinexColors.success : _apiHealthy == false ? theme.colorScheme.error : TrinexColors.muted)),
                    ]),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: _loading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
                label: const Text('تحديث البيانات'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (_loading && _stats == null)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _stats == null)
            _ErrorPanel(message: _error!, onRetry: _load)
          else ...[
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: TrinexColors.warning),
                  const SizedBox(width: 10),
                  Expanded(child: Text('تعذر تحديث بعض البيانات. المعروض هو آخر تحميل ناجح. ${_error!}', style: const TextStyle(color: TrinexColors.ink))),
                ]),
              ),
            LayoutBuilder(builder: (context, constraints) {
              // Keep the general statistics cards in two columns on mobile.
              final columns = constraints.maxWidth >= 1250 ? 4 : 2;
              final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: stats.map((item) => SizedBox(width: width, child: _StatCard(data: item))).toList(),
              );
            }),
          ],
          const SizedBox(height: 30),
          Row(children: [
            Expanded(child: Text('الوصول السريع', style: theme.textTheme.titleLarge)),
            Text('${quickActions.length} أقسام متاحة', style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 14),
          if (quickActions.isEmpty)
            const _EmptyQuickActions()
          else
            LayoutBuilder(builder: (context, constraints) {
              // Keep the overview quick-action cards in two columns on phones.
              // Wider layouts retain the existing 2/3-column behavior.
              final columns = constraints.maxWidth >= 1100 ? 3 : 2;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: quickActions.map((action) => SizedBox(
                  width: width,
                  child: _QuickActionCard(action: action, onTap: () => widget.onNavigate(action.section)),
                )).toList(),
              );
            }),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE5FF)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.verified_user_outlined, color: TrinexColors.brand),
              ),
              const SizedBox(width: 13),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('مساحة إدارة آمنة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: TrinexColors.ink)),
                SizedBox(height: 5),
                Text('تُعرض الأقسام وفق دور حسابك. يظل الخادم هو المسؤول عن التحقق من صلاحية كل عملية، حتى لو تغيّرت واجهة التطبيق.', style: TextStyle(color: TrinexColors.muted, height: 1.5)),
              ])),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  const _StatData(this.title, this.value, this.icon, this.color);
  final String title;
  final int value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: data.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
            child: Icon(data.icon, color: data.color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 7),
            Text(data.value.toString(), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w800)),
          ])),
        ]),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.section, this.title, this.subtitle, this.icon);
  final AdminSection section;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onTap});
  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 220;
      final icon = Container(
        padding: EdgeInsets.all(compact ? 9 : 11),
        decoration: BoxDecoration(color: const Color(0xFFEFF3FF), borderRadius: BorderRadius.circular(12)),
        child: Icon(action.icon, color: TrinexColors.brand, size: compact ? 21 : 24),
      );
      final labels = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(action.title, style: const TextStyle(fontWeight: FontWeight.w700, color: TrinexColors.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(action.subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: compact ? 2 : 3, overflow: TextOverflow.ellipsis),
        ],
      );
      return Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(compact ? 12 : 17),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: TrinexColors.border)),
            child: compact
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [icon, const Spacer(), const Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: TrinexColors.muted)]),
                    const SizedBox(height: 10),
                    labels,
                  ])
                : Row(children: [
                    icon,
                    const SizedBox(width: 13),
                    Expanded(child: labels),
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: TrinexColors.muted),
                  ]),
          ),
        ),
      );
    });
  }
}

class _EmptyQuickActions extends StatelessWidget {
  const _EmptyQuickActions();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد أقسام إضافية مرتبطة بدور حسابك.')));
}

class _NavigationRailPanel extends StatelessWidget {
  const _NavigationRailPanel({
    required this.selected,
    required this.sections,
    required this.onSelect,
    required this.session,
    required this.onSignOut,
  });

  final AdminSection selected;
  final List<AdminSection> sections;
  final ValueChanged<AdminSection> onSelect;
  final AdminSession session;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TRINEX', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
                Text('لوحة الإدارة', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ])),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: selected == section,
                      selectedTileColor: const Color(0xFFEAF1FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(section.icon),
                      title: Text(section.title, style: const TextStyle(fontSize: 14)),
                      onTap: () => onSelect(section),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(session.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(AdminPermissions.roleLabel(session.role), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ),
        ],
      ),
    );
  }
}

List<AdminSection> _compactSections(List<AdminSection> visible) {
  const preferred = [
    AdminSection.overview,
    AdminSection.students,
    AdminSection.content,
    AdminSection.materials,
    AdminSection.account,
  ];
  final result = preferred.where(visible.contains).take(5).toList();
  return result.isEmpty ? [AdminSection.overview] : result;
}

class _CompactBottomBar extends StatelessWidget {
  const _CompactBottomBar({required this.selected, required this.sections, required this.onSelect});
  final AdminSection selected;
  final List<AdminSection> sections;
  final ValueChanged<AdminSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = sections.indexOf(selected);
    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) => onSelect(sections[index]),
      destinations: sections.map((section) => NavigationDestination(
        icon: Icon(section.icon),
        label: section.title,
      )).toList(),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.cloud_off_outlined, size: 32),
          const SizedBox(height: 10),
          const Text('تعذر تحميل لوحة المعلومات', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
        ]),
      ),
    );
  }
}

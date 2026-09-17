import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/repositories/student_repository.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/responsive_content.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../../shared/widgets/trinex_brand.dart';
import '../eino/eino_face.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _signedIn = false;
  bool _sessionLoaded = false;
  String? _studentName;
  String? _studentNumber;
  String? _departmentName;
  String? _semesterName;
  String? _semesterId;

  ApiClient? _client;
  AuthStorage? _storage;
  StudentRepository? _studentRepo;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final storage = await AuthStorage.create();
    _storage = storage;
    final signedIn = await storage.isLoggedIn;

    String? name;
    String? number;
    String? dept;
    String? sem;
    String? semId;

    if (signedIn) {
      final client = ApiClient(baseUrl: AppConstants.apiBaseUrl, authStorage: storage);
      _client = client;
      _studentRepo = StudentRepository(client);

      name = await storage.studentName;
      number = await storage.studentNumber;
      dept = await storage.departmentName;
      sem = await storage.semesterName;
      semId = await storage.currentSemesterId;

      // Also try to refresh profile cache if fields are missing
      if (dept == null || sem == null) {
        try {
          final profile = await _studentRepo!.profile();
          name = profile.name;
          number = profile.studentNumber;
          dept = profile.departmentName;
          sem = profile.semesterName;
          semId = profile.semesterId;
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _studentName = name;
      _studentNumber = number;
      _departmentName = dept;
      _semesterName = sem;
      _semesterId = semId;
      _sessionLoaded = true;
    });
  }

  Future<void> _openSemesterPicker() async {
    final repo = _studentRepo;
    final storage = _storage;
    if (repo == null || storage == null) return;
    final l10n = AppLocalizations.of(context);

    try {
      final semesters = await repo.semesters();
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('updateSemesterTitle'),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  ...semesters.map((s) {
                    final sid = s['id']?.toString() ?? '';
                    final sname = s['name']?.toString() ?? '';
                    final isCurrent = sid == _semesterId;
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      selected: isCurrent,
                      selectedTileColor: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.1),
                      leading: Icon(
                        isCurrent ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isCurrent ? Theme.of(ctx).colorScheme.primary : null,
                      ),
                      title: Text(sname, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        try {
                          await repo.updateSemester(semesterId: sid);
                          await storage.updateCachedSemester(semesterId: sid, semesterName: sname);
                          if (!mounted) return;
                          setState(() {
                            _semesterId = sid;
                            _semesterName = sname;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.t('semesterUpdatedSuccess')),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                          );
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // App Bar
        SliverAppBar(
          pinned: true,
          toolbarHeight: 66,
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          titleSpacing: DesignTokens.space16,
          title: const TrinexLogo(width: 128),
          actions: [
            _HeaderIconButton(
              icon: Icons.notifications_none_rounded,
              onTap: () => context.push('/notifications'),
              tooltip: l10n.t('notifications'),
            ),
            const SizedBox(width: 8),
            _HeaderIconButton(
              icon: Icons.settings_outlined,
              onTap: () => context.push('/settings'),
              tooltip: l10n.t('settings'),
            ),
            const SizedBox(width: 12),
          ],
        ),

        // Body Content
        SliverToBoxAdapter(
          child: ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 42),
            child: StaggeredFadeIn(
              delay: const Duration(milliseconds: 35),
              children: [
                if (!_sessionLoaded)
                  const _LoadingSkeleton()
                else if (_signedIn)
                  _buildRegisteredStudentExperience(context, l10n)
                else
                  _buildGuestExperience(context, l10n),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Registered Student Flow (Academic Focus)
  // -------------------------------------------------------------
  Widget _buildRegisteredStudentExperience(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Personal Academic Banner Card
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school_rounded, color: primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _studentName ?? _studentNumber ?? l10n.t('studentFallback'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _departmentName ?? 'كلية الهندسة والعمارة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Semester Badge with Change Button
                  InkWell(
                    onTap: _openSemesterPicker,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 14, color: primary),
                          const SizedBox(width: 4),
                          Text(
                            _semesterName ?? l10n.t('semester'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Academic Actions
        _SectionHeader(
          title: l10n.t('quickAccess'),
          action: l10n.t('allServices'),
          onTap: () => context.push('/more'),
        ),
        const SizedBox(height: 10),
        _AcademicQuickGrid(onSemesterTap: _openSemesterPicker),
        const SizedBox(height: 22),

        // Progress & XP Card
        _StudyProgressCard(signedIn: true),
        const SizedBox(height: 22),

        // Eino Academic Helper Card
        const _EinoAcademicCard(),
        const SizedBox(height: 24),

        // Engineering Tools Shortcut
        _EngineeringToolsBanner(),
        const SizedBox(height: 24),

        // Latest Updates from Association & College
        _SectionHeader(
          title: l10n.t('latestUpdates'),
          action: l10n.t('viewAll'),
          onTap: () => context.push('/news'),
        ),
        const SizedBox(height: 10),
        _UpdatesRow(),
      ],
    );
  }

  // -------------------------------------------------------------
  // Guest Flow (General & Onboarding Focus)
  // -------------------------------------------------------------
  Widget _buildGuestExperience(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Guest Welcome Hero Card
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'وضع الزائر',
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t('guestWelcomeTitle'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.t('guestWelcomeSubtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/login'),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: Text(l10n.t('signIn')),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/register'),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: Text(l10n.t('createAccount')),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Locked Academic Materials Card (Polite callout explaining locked state)
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, color: theme.colorScheme.error, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('studentLockedCardTitle'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('studentLockedCardDesc'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Engineering Tools (Available to everyone, including guests!)
        _SectionHeader(
          title: l10n.t('toolsTitle'),
          action: l10n.t('viewAll'),
          onTap: () => context.push('/tools'),
        ),
        const SizedBox(height: 10),
        _EngineeringToolsBanner(),
        const SizedBox(height: 24),

        // Eino Chat Hero for Visitors
        const _EinoHero(),
        const SizedBox(height: 24),

        // College & Association News / Events
        _SectionHeader(
          title: l10n.t('latestUpdates'),
          action: l10n.t('viewAll'),
          onTap: () => context.push('/news'),
        ),
        const SizedBox(height: 10),
        _UpdatesRow(),
      ],
    );
  }
}

// -------------------------------------------------------------
// Component Widgets
// -------------------------------------------------------------

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action, required this.onTap});
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _AcademicQuickGrid extends StatelessWidget {
  const _AcademicQuickGrid({required this.onSemesterTap});
  final VoidCallback onSemesterTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (Icons.menu_book_rounded, l10n.t('materials'), l10n.t('lecturesFiles'), '/materials'),
      (Icons.calendar_month_rounded, l10n.t('schedule'), l10n.t('upcomingClasses'), '/schedule'),
      (Icons.handyman_outlined, l10n.t('toolsTitle'), l10n.t('engineeringTools'), '/tools'),
      (Icons.emoji_events_outlined, l10n.t('badgesTitle'), l10n.t('xpLevel'), '/badges'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth < 560;
        const gap = 10.0;
        final cardWidth = twoCols
            ? (constraints.maxWidth - gap) / 2
            : (constraints.maxWidth - (gap * 3)) / 4;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                height: twoCols ? 114 : 128,
                child: AppCard(
                  onTap: () => context.push(item.$4),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.$1, color: Theme.of(context).colorScheme.primary, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EngineeringToolsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AppCard(
      onTap: () => context.push('/tools'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.handyman_rounded, color: primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('toolsTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.t('toolsSubtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.arrow_back_ios_rounded
                : Icons.arrow_forward_ios_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StudyProgressCard extends StatelessWidget {
  const _StudyProgressCard({required this.signedIn});
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      onTap: () => context.push(signedIn ? '/progress' : '/login'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_graph_rounded, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signedIn ? l10n.t('studyProgress') : l10n.t('startStudy'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  signedIn ? l10n.t('studyProgressSubtitle') : l10n.t('startStudySubtitle'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: signedIn ? 0.72 : 0,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.arrow_back_ios_rounded
                : Icons.arrow_forward_ios_rounded,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _EinoAcademicCard extends StatelessWidget {
  const _EinoAcademicCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AppCard(
      onTap: () => context.push('/eino?from=home'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const EinoFace(size: 52, mood: EinoMood.happy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.t('eino'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.t('quickPromptEino'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => context.push('/eino?from=home'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(l10n.t('startChat')),
          ),
        ],
      ),
    );
  }
}

class _EinoHero extends StatelessWidget {
  const _EinoHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              AppColors.navy,
              const Color(0xFF1B3B59),
            ],
          ),
        ),
        child: Stack(
          children: [
            const PositionedDirectional(
              end: 10,
              bottom: -6,
              child: EinoFace(size: 146, mood: EinoMood.happy),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 140, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'EINO AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.t('einoCardTitle'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => context.push('/eino?from=home'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.t('startChat')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdatesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 126,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _UpdateCard(
            icon: Icons.campaign_rounded,
            title: l10n.t('announcements'),
            subtitle: l10n.t('announcementsSubtitle'),
            route: '/announcements',
          ),
          const SizedBox(width: 10),
          _UpdateCard(
            icon: Icons.article_rounded,
            title: l10n.t('news'),
            subtitle: l10n.t('newsSubtitle'),
            route: '/news',
          ),
          const SizedBox(width: 10),
          _UpdateCard(
            icon: Icons.event_available_rounded,
            title: l10n.t('activities'),
            subtitle: l10n.t('activitiesSubtitle'),
            route: '/activities',
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 228,
      child: AppCard(
        onTap: () => context.push(route),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: primary),
                ),
                const Spacer(),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.north_west_rounded
                      : Icons.north_east_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }
}

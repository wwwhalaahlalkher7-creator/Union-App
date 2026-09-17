import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_version.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/repositories/student_repository.dart';
import '../../shared/widgets/app_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    required this.locale,
    required this.onLocaleChanged,
    this.accentColorId,
    this.onAccentColorChanged,
    super.key,
  });

  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final String? accentColorId;
  final ValueChanged<String>? onAccentColorChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _signedIn = false;
  String? _studentName;
  String? _studentNumber;
  String? _departmentName;
  String? _semesterName;
  String? _semesterId;

  AuthStorage? _storage;
  ApiClient? _client;
  StudentRepository? _studentRepo;

  @override
  void initState() {
    super.initState();
    _loadStudentContext();
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  Future<void> _loadStudentContext() async {
    final storage = await AuthStorage.create();
    _storage = storage;
    final signedIn = await storage.isLoggedIn;
    if (!mounted) return;

    if (signedIn) {
      final client = ApiClient(baseUrl: AppConstants.apiBaseUrl, authStorage: storage);
      _client = client;
      _studentRepo = StudentRepository(client);

      final name = await storage.studentName;
      final number = await storage.studentNumber;
      final dept = await storage.departmentName;
      final sem = await storage.semesterName;
      final semId = await storage.currentSemesterId;

      if (!mounted) return;
      setState(() {
        _signedIn = true;
        _studentName = name;
        _studentNumber = number;
        _departmentName = dept;
        _semesterName = sem;
        _semesterId = semId;
      });
    } else {
      setState(() => _signedIn = false);
    }
  }

  Future<void> _changeSemester() async {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Account Status Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _signedIn ? Icons.school_rounded : Icons.person_outline_rounded,
                    color: primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _signedIn
                            ? (_studentName ?? _studentNumber ?? l10n.t('studentFallback'))
                            : l10n.t('guestWelcomeTitle'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _signedIn
                            ? '${_departmentName ?? ''} • ${_semesterName ?? ''}'
                            : l10n.t('signInToStudy'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_signedIn) {
                      context.push('/student');
                    } else {
                      context.push('/login');
                    }
                  },
                  child: Text(_signedIn ? l10n.t('studentProfile') : l10n.t('signIn')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // If signed in, Semester Change Option
          if (_signedIn) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.calendar_month_rounded, color: primary, size: 20),
                ),
                title: Text(l10n.t('updateSemesterTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_semesterName ?? l10n.t('semester')),
                trailing: TextButton(
                  onPressed: _changeSemester,
                  child: Text(l10n.t('changeSemester')),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Appearance Card: Theme Mode & Accent Colors
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.t('appearance'),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Theme Mode Segment
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(value: ThemeMode.system, label: Text(l10n.t('system')), icon: const Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.light, label: Text(l10n.t('light')), icon: const Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: ThemeMode.dark, label: Text(l10n.t('dark')), icon: const Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {widget.currentThemeMode},
                  onSelectionChanged: (set) {
                    HapticFeedback.selectionClick();
                    widget.onThemeModeChanged(set.first);
                  },
                ),
                const SizedBox(height: 18),

                // Accent Color Presets
                Text(
                  l10n.t('accentColor'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: AppAccentColor.presets.map((colorPreset) {
                    final isSelected = (widget.accentColorId ?? 'orange') == colorPreset.id;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onAccentColorChanged?.call(colorPreset.id);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colorPreset.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: colorPreset.primary.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Language Setting
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.language_rounded, color: primary, size: 20),
              ),
              title: Text(l10n.t('language'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_languageLabel(l10n, widget.locale)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _showLanguagePicker(context, l10n),
            ),
          ),
          const SizedBox(height: 12),

          // Replay Onboarding
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.slideshow_rounded, color: primary, size: 20),
              ),
              title: Text(l10n.t('replayOnboarding'), style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => context.push('/onboarding'),
            ),
          ),
          const SizedBox(height: 12),

          // About & Version
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.info_outline_rounded, color: primary, size: 20),
              ),
              title: Text(l10n.t('about'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('v${AppVersion.current}'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => context.push('/about'),
            ),
          ),
        ],
      ),
    );
  }

  String _languageLabel(AppLocalizations l10n, Locale? value) {
    if (value == null) return l10n.t('automatic');
    return switch (value.languageCode) {
      'en' => l10n.t('english'),
      'fr' => l10n.t('french'),
      _ => l10n.t('arabic'),
    };
  }

  Future<void> _showLanguagePicker(BuildContext context, AppLocalizations l10n) async {
    final selected = await showModalBottomSheet<Locale?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              title: Text(l10n.t('arabic')),
              trailing: widget.locale?.languageCode == 'ar' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () => Navigator.pop(ctx, const Locale('ar')),
            ),
            ListTile(
              title: Text(l10n.t('english')),
              trailing: widget.locale?.languageCode == 'en' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () => Navigator.pop(ctx, const Locale('en')),
            ),
            ListTile(
              title: Text(l10n.t('french')),
              trailing: widget.locale?.languageCode == 'fr' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () => Navigator.pop(ctx, const Locale('fr')),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null) widget.onLocaleChanged(selected);
  }
}

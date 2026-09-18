import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_version.dart';
import '../../core/theme/design_tokens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.currentThemeMode, required this.onThemeModeChanged, required this.locale, required this.onLocaleChanged, this.accentColorId, this.onAccentColorChanged, super.key});
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final String? accentColorId;
  final ValueChanged<String>? onAccentColorChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = accentColorId ?? 'purple';
    return Scaffold(
      backgroundColor: dark ? AppColors.background : const Color(0xFFF5F7FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(34), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: AppColors.purple.withValues(alpha: .13), blurRadius: 40)]),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(height: 4, decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.purple, Color(0xFFB24DFF)]))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 24, 24, 22),
                      child: Row(
                        children: [
                          IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, size: 34, color: AppColors.muted)),
                          const Spacer(),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('الإعدادات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                              SizedBox(height: 5),
                              Text('تخصيص الواجهة والسمات وخيارات العرض', style: TextStyle(color: AppColors.muted, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(width: 18),
                          Container(width: 66, height: 66, decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.palette_outlined, color: Colors.white, size: 34)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(38, 22, 38, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Label('نمط العرض'),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _ModeCard('الوضع الداكن', Icons.dark_mode_outlined, currentThemeMode == ThemeMode.dark || (currentThemeMode == ThemeMode.system && dark), () => onThemeModeChanged(ThemeMode.dark))),
                            const SizedBox(width: 16),
                            Expanded(child: _ModeCard('الوضع الفاتح', Icons.light_mode_outlined, currentThemeMode == ThemeMode.light, () => onThemeModeChanged(ThemeMode.light))),
                          ]),
                          const SizedBox(height: 30),
                          const _Label('اللون المميز (ACCENT COLOR)'),
                          const SizedBox(height: 14),
                          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                            for (final color in AppAccentColor.presets)
                              Padding(padding: const EdgeInsetsDirectional.only(end: 12), child: _AccentCard(color: color, selected: selected == color.id, onTap: onAccentColorChanged == null ? null : () => onAccentColorChanged!(color.id))),
                          ])),
                          const SizedBox(height: 30),
                          const _Label('اللغة / LANGUAGE'),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: _LanguageCard('العربية (RTL)', const Locale('ar'), locale?.languageCode == 'ar', onLocaleChanged)),
                            const SizedBox(width: 16),
                            Expanded(child: _LanguageCard('English (LTR)', const Locale('en'), locale?.languageCode == 'en', onLocaleChanged)),
                          ]),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
                            child: Column(
                              children: [
                                Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    const Text('TRINEX Engine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 7),
                                    Text('v${AppVersion.name}  •  Build #${AppVersion.build}  •  2026-09-17', style: const TextStyle(color: AppColors.muted)),
                                  ])),
                                  OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد تحديثات جديدة — Mock Data'))), icon: const Icon(Icons.refresh_rounded), label: const Text('فحص التحديثات')),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override Widget build(BuildContext context) => Text(text, textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
}

class _ModeCard extends StatelessWidget {
  const _ModeCard(this.label, this.icon, this.selected, this.onTap);
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Container(height: 64, decoration: BoxDecoration(color: selected ? AppColors.elevated : Colors.transparent, borderRadius: BorderRadius.circular(24), border: Border.all(color: selected ? AppColors.cyan : AppColors.border, width: selected ? 2 : 1)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(width: 10), Icon(icon, color: selected ? AppColors.purple : AppColors.muted)])));
}

class _AccentCard extends StatelessWidget {
  const _AccentCard({required this.color, required this.selected, required this.onTap});
  final AppAccentColor color; final bool selected; final VoidCallback? onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Container(width: 112, height: 146, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: selected ? AppColors.elevated : Colors.transparent, borderRadius: BorderRadius.circular(22), border: Border.all(color: selected ? AppColors.cyan : AppColors.border, width: selected ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: color.primary), child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 26) : null), const SizedBox(height: 12), Text(color.nameAr, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35)), Text('(${color.nameEn})', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12))])));
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard(this.label, this.value, this.selected, this.onChanged);
  final String label; final Locale value; final bool selected; final ValueChanged<Locale?> onChanged;
  @override Widget build(BuildContext context) => InkWell(onTap: () => onChanged(value), borderRadius: BorderRadius.circular(24), child: Container(height: 60, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? const Color(0xFF0C3851) : Colors.transparent, borderRadius: BorderRadius.circular(24), border: Border.all(color: selected ? AppColors.cyan : AppColors.border, width: selected ? 2 : 1)), child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.muted, fontWeight: FontWeight.w800, fontSize: 14))));
}

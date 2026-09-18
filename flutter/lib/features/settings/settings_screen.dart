import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_version.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/update/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.currentThemeMode, required this.onThemeModeChanged, required this.locale, required this.onLocaleChanged, this.accentColorId, this.onAccentColorChanged, super.key});
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
  bool _checkingUpdate = false;

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final info = await const UpdateService().check();
      if (!mounted) return;
      final service = const UpdateService();
      final message = info == null
          ? 'تعذر التحقق من التحديثات حاليًا.'
          : service.isOptional(info)
              ? 'يتوفر تحديث جديد: ${info.currentVersion}'
              : 'لا توجد تحديثات جديدة.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = AppAccentColor.presets.firstWhere((color) => color.primary == context.colors.primary, orElse: () => AppAccentColor.fromId(widget.accentColorId)).id;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.56),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Container(
                decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(30.6), border: Border.all(color: context.colors.outline), boxShadow: [BoxShadow(color: context.colors.primary.withValues(alpha: .13), blurRadius: 40)]),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(height: 4, decoration: BoxDecoration(gradient: LinearGradient(colors: [context.colors.primary, context.colors.secondary]))),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(27.6, 22.08, 22.08, 20.24),
                      child: Row(
                        children: [
                          IconButton(onPressed: () => context.pop(), icon: Icon(Icons.close_rounded, size: 34, color: context.colors.onSurfaceVariant)),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('الإعدادات', style: TextStyle(fontSize: 22.1, fontWeight: FontWeight.w900)),
                              SizedBox(height: 5),
                              Text('تخصيص الواجهة والسمات وخيارات العرض', style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 12.9)),
                            ],
                          ),
                          SizedBox(width: 18),
                          Container(width: 60, height: 60, decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.palette_outlined, color: Colors.white, size: 34)),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(34.96, 20.24, 34.96, 31.28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Label('نمط العرض'),
                          SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _ModeCard('الوضع الداكن', Icons.dark_mode_outlined, widget.currentThemeMode == ThemeMode.dark || (widget.currentThemeMode == ThemeMode.system && dark), () => widget.onThemeModeChanged(ThemeMode.dark))),
                            SizedBox(width: 16),
                            Expanded(child: _ModeCard('الوضع الفاتح', Icons.light_mode_outlined, widget.currentThemeMode == ThemeMode.light, () => widget.onThemeModeChanged(ThemeMode.light))),
                          ]),
                          SizedBox(height: 30),
                          const _Label('اللون المميز (ACCENT COLOR)'),
                          SizedBox(height: 14),
                          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                            for (final color in AppAccentColor.presets)
                              Padding(padding: const EdgeInsetsDirectional.only(end: 11.04), child: _AccentCard(color: color, selected: selected == color.id, onTap: widget.onAccentColorChanged == null ? null : () => widget.onAccentColorChanged!(color.id))),
                          ])),
                          SizedBox(height: 30),
                          const _Label('اللغة / LANGUAGE'),
                          SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _LanguageCard('العربية (RTL)', const Locale('ar'), widget.locale?.languageCode == 'ar', widget.onLocaleChanged),
                              _LanguageCard('English (LTR)', const Locale('en'), widget.locale?.languageCode == 'en', widget.onLocaleChanged),
                              _LanguageCard('Français (LTR)', const Locale('fr'), widget.locale?.languageCode == 'fr', widget.onLocaleChanged),
                            ],
                          ),

                          SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(16.56),
                            decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.colors.outline)),
                            child: Column(
                              children: [
                                Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('TRINEX Engine', style: TextStyle(fontSize: 18.4, fontWeight: FontWeight.w900)),
                                    SizedBox(height: 7),
                                    Text('v${AppVersion.name}  •  Build #${AppVersion.build}  •  2026-09-17', style: TextStyle(color: context.colors.onSurfaceVariant)),
                                  ])),
                                  OutlinedButton.icon(onPressed: _checkingUpdate ? null : _checkForUpdate, icon: _checkingUpdate ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.refresh_rounded), label: Text(_checkingUpdate ? 'جارٍ الفحص' : 'فحص التحديثات')),
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
  @override Widget build(BuildContext context) => Text(text, textAlign: TextAlign.end, style: TextStyle(fontSize: 16.6, fontWeight: FontWeight.w800));
}

class _ModeCard extends StatelessWidget {
  const _ModeCard(this.label, this.icon, this.selected, this.onTap);
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(height: 64, decoration: BoxDecoration(color: selected ? context.colors.surfaceContainerHigh : Colors.transparent, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? context.colors.secondary : context.colors.outline, width: selected ? 2 : 1)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w800)), SizedBox(width: 10), Icon(icon, color: selected ? context.colors.primary : context.colors.onSurfaceVariant)])));
}

class _AccentCard extends StatelessWidget {
  const _AccentCard({required this.color, required this.selected, required this.onTap});
  final AppAccentColor color; final bool selected; final VoidCallback? onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(19.8), child: Container(width: 104, height: 134, padding: const EdgeInsets.all(11.04), decoration: BoxDecoration(color: selected ? context.colors.surfaceContainerHigh : Colors.transparent, borderRadius: BorderRadius.circular(19.8), border: Border.all(color: selected ? context.colors.secondary : context.colors.outline, width: selected ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: color.primary), child: selected ? Icon(Icons.check_rounded, color: Colors.white, size: 26) : null), SizedBox(height: 12), Text(color.nameAr, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, height: 1.35)), Text('(${color.nameEn})', textAlign: TextAlign.center, style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 11))])));
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard(this.label, this.value, this.selected, this.onChanged);
  final String label; final Locale value; final bool selected; final ValueChanged<Locale?> onChanged;
  @override Widget build(BuildContext context) => InkWell(onTap: () => onChanged(value), borderRadius: BorderRadius.circular(18), child: Container(height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? context.colors.primary : Colors.transparent, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? context.colors.secondary : context.colors.outline, width: selected ? 2 : 1)), child: Text(label, style: TextStyle(color: selected ? Colors.white : context.colors.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12.9))));
}

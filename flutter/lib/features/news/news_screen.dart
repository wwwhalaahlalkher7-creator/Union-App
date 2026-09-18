import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});
  @override Widget build(BuildContext context) {
    return _PageScroll(children: [
      _SectionHeader(icon: Icons.article_outlined, title: 'أخبار رابطة كلية الهندسة والعمارة', subtitle: 'منصة رابطة كلية الهندسة والعمارة • الإعلانات المعتمدة والأنشطة الطلابية'),
      const SizedBox(height: 18),
      SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, children: const [_FilterChip('جميع الأخبار', true), _FilterChip('بيانات رسمية', false), _FilterChip('معارض ومؤتمرات', false), _FilterChip('أنشطة طلابية', false)])),
      const SizedBox(height: 20),
      for (final item in MockData.news) Padding(padding: const EdgeInsets.only(bottom: 18), child: _NewsCard(item: item)),
      const _Footer(),
    ]);
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item}); final MockNewsItem item;
  @override Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final tagColor = item.category == 'official' ? AppColors.gold : item.category == 'event' ? AppColors.cyan : AppColors.purple;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: item.pinned ? AppColors.gold.withValues(alpha: .45) : AppColors.border, width: item.pinned ? 1.5 : 1)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 250, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF29344A), Color(0xFF0A101F)])), child: Stack(children: [
          PositionedDirectional(top: 22, end: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .48), borderRadius: BorderRadius.circular(14)), child: Text(item.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
          Center(child: Icon(item.category == 'event' ? Icons.event_available_rounded : item.category == 'official' ? Icons.campaign_rounded : Icons.groups_rounded, size: 82, color: accent.withValues(alpha: .22))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(28, 18, 28, 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(item.date, style: const TextStyle(color: AppColors.muted, fontSize: 15)), const SizedBox(width: 8), const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.muted), const Spacer(), if (item.pinned) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF5B2A08), borderRadius: BorderRadius.circular(10)), child: const Text('إعلان مثبت 📌', style: TextStyle(color: Color(0xFFFFB629), fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 18),
          Text(item.title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 22, height: 1.35, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Text(item.summary, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.muted, fontSize: 16, height: 1.65)),
          const SizedBox(height: 18),
          Row(children: [Text('قراءة الإعلان كاملاً', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(width: 6), Icon(Icons.arrow_back_rounded, color: accent), const Spacer(), Text('${item.likes}', style: const TextStyle(color: AppColors.muted)), const SizedBox(width: 7), Icon(Icons.thumb_up_alt_outlined, color: AppColors.cyan), const SizedBox(width: 24), Text('${item.comments}', style: const TextStyle(color: AppColors.muted)), const SizedBox(width: 7), const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.muted)]),
        ])),
      ]),
    );
  }
}

class _PageScroll extends StatelessWidget { const _PageScroll({required this.children}); final List<Widget> children; @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(36, 28, 36, 120), physics: const BouncingScrollPhysics(), children: children); }
class _SectionHeader extends StatelessWidget { const _SectionHeader({required this.icon, required this.title, required this.subtitle}); final IconData icon; final String title, subtitle; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Row(mainAxisAlignment: MainAxisAlignment.end, children: [Flexible(child: Text(title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))), const SizedBox(width: 14), Icon(icon, color: AppColors.cyan, size: 34)]), const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.muted, fontSize: 16))]); }
class _FilterChip extends StatelessWidget { const _FilterChip(this.label, this.selected); final String label; final bool selected; @override Widget build(BuildContext context) => Container(margin: const EdgeInsetsDirectional.only(start: 10), padding: const EdgeInsets.symmetric(horizontal: 26), alignment: Alignment.center, decoration: BoxDecoration(color: selected ? Colors.white : AppColors.elevated, borderRadius: BorderRadius.circular(28), border: Border.all(color: selected ? Colors.white : AppColors.border)), child: Text(label, style: TextStyle(color: selected ? const Color(0xFF111827) : AppColors.muted, fontSize: 16, fontWeight: FontWeight.w800))); }
class _Footer extends StatelessWidget { const _Footer(); @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.only(top: 16), child: Column(children: [Divider(color: AppColors.border), SizedBox(height: 18), Text('2026 © رابطة كلية الهندسة والعمارة - منصة TRINEX', style: TextStyle(color: AppColors.muted, fontSize: 15)), SizedBox(height: 7), Text('منصة الرابطة الطلابية • المساعد الأكاديمي إينو', style: TextStyle(color: AppColors.muted, fontSize: 14))])); }

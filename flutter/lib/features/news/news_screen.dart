import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';
import 'package:go_router/go_router.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  String filter = 'all';
  final Set<String> liked = <String>{};

  @override
  Widget build(BuildContext context) {
    final visible = MockData.news.where((item) => filter == 'all' || item.category == filter).toList();
    return _PageScroll(children: [
      const _SectionHeader(icon: Icons.article_outlined, title: 'أخبار رابطة كلية الهندسة والعمارة', subtitle: 'منصة رابطة كلية الهندسة والعمارة • الإعلانات المعتمدة والأنشطة الطلابية'),
      const SizedBox(height: 14),
      SizedBox(height: 46, child: ListView(scrollDirection: Axis.horizontal, children: [
        _FilterChip('جميع الأخبار', filter == 'all', () => setState(() => filter = 'all')),
        _FilterChip('بيانات رسمية', filter == 'official', () => setState(() => filter = 'official')),
        _FilterChip('معارض ومؤتمرات', filter == 'event', () => setState(() => filter = 'event')),
        _FilterChip('أنشطة طلابية', filter == 'activity', () => setState(() => filter = 'activity')),
      ])),
      const SizedBox(height: 16),
      if (visible.isEmpty)
        const Padding(padding: EdgeInsets.all(40), child: Text('لا توجد أخبار في هذا التصنيف.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 15)))
      else
        for (final item in visible)
          Padding(padding: const EdgeInsets.only(bottom: 18), child: _NewsCard(
            item: item,
            liked: liked.contains(item.title),
            onRead: () => context.push('/news/detail', extra: item),
            onLike: () => setState(() => liked.add(item.title)),
            onComments: () => _showComments(item),
          )),
    ]);
  }

  void _showComments(MockNewsItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('التعليقات (${item.comments})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          const Text('هذه تعليقات تجريبية محلية. سيتم تفعيل الردود عند ربط Backend.', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('إغلاق'))),
        ]),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.liked, required this.onRead, required this.onLike, required this.onComments});
  final MockNewsItem item;
  final bool liked;
  final VoidCallback onRead;
  final VoidCallback onLike;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final tagColor = item.category == 'official' ? AppColors.gold : item.category == 'event' ? AppColors.cyan : AppColors.purple;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onRead,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: item.pinned ? AppColors.gold.withValues(alpha: .45) : AppColors.border, width: item.pinned ? 1.5 : 1)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 210, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF29344A), Color(0xFF0A101F)])), child: Stack(children: [
          PositionedDirectional(top: 22, end: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), decoration: BoxDecoration(color: tagColor.withValues(alpha: .18), borderRadius: BorderRadius.circular(14), border: Border.all(color: tagColor.withValues(alpha: .45))), child: Text(item.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
          Center(child: Icon(item.category == 'event' ? Icons.event_available_rounded : item.category == 'official' ? Icons.campaign_rounded : Icons.groups_rounded, size: 82, color: accent.withValues(alpha: .22))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(item.date, style: const TextStyle(color: AppColors.muted, fontSize: 13)), const SizedBox(width: 8), const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.muted), const Spacer(), if (item.pinned) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF5B2A08), borderRadius: BorderRadius.circular(10)), child: const Text('إعلان مثبت 📌', style: TextStyle(color: Color(0xFFFFB629), fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 18),
          Text(item.title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Text(item.summary, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.55)),
          const SizedBox(height: 18),
          Row(children: [
            const Spacer(),
            Text('${item.likes + (liked ? 1 : 0)}', style: const TextStyle(color: AppColors.muted)), const SizedBox(width: 7),
            InkWell(onTap: liked ? null : onLike, borderRadius: BorderRadius.circular(18), child: Icon(liked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined, color: AppColors.cyan)),
            const SizedBox(width: 24), Text('${item.comments}', style: const TextStyle(color: AppColors.muted)), const SizedBox(width: 7),
            InkWell(onTap: onComments, borderRadius: BorderRadius.circular(18), child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.muted)),
          ]),
        ])),
          ]),
        ),
      ),
    );
  }
}

class _PageScroll extends StatelessWidget { const _PageScroll({required this.children}); final List<Widget> children; @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(24, 22, 24, 100), physics: const BouncingScrollPhysics(), children: children); }
class _SectionHeader extends StatelessWidget { const _SectionHeader({required this.icon, required this.title, required this.subtitle}); final IconData icon; final String title, subtitle; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Row(mainAxisAlignment: MainAxisAlignment.end, children: [Flexible(child: Text(title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))), const SizedBox(width: 14), Icon(icon, color: AppColors.cyan, size: 34)]), const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.muted, fontSize: 14))]); }
class _FilterChip extends StatelessWidget { const _FilterChip(this.label, this.selected, this.onTap); final String label; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(28), child: Container(margin: const EdgeInsetsDirectional.only(start: 10), padding: const EdgeInsets.symmetric(horizontal: 26), alignment: Alignment.center, decoration: BoxDecoration(color: selected ? Colors.white : AppColors.elevated, borderRadius: BorderRadius.circular(28), border: Border.all(color: selected ? Colors.white : AppColors.border)), child: Text(label, style: TextStyle(color: selected ? const Color(0xFF111827) : AppColors.muted, fontSize: 14, fontWeight: FontWeight.w800)))); }

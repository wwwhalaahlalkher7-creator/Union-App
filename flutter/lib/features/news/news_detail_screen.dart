import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({required this.item, super.key});
  final MockNewsItem item;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text('تفاصيل الخبر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Expanded(child: Text(item.date, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(10)), child: Text(item.category, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 12))),
              ]),
              const SizedBox(height: 18),
              Text(item.title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 22, height: 1.35, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              Text(item.summary, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.7)),
              if (item.pinned) ...[
                const SizedBox(height: 18),
                const Align(alignment: AlignmentDirectional.centerEnd, child: Text('إعلان مثبت 📌', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800))),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

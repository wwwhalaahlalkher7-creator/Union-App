import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/mock_data.dart';

class SystemScreen extends StatelessWidget {
  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = MockData.student;
    final progress = s.xp / (s.xp + s.xpToNext);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(30, 28, 30, 26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF151E45), Color(0xFF1E1244), Color(0xFF083448)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.purple.withValues(alpha: .35)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('رتبة المهندس:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        Text(s.levelName, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 7),
                        Text('${s.name} • ${s.department}', style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('XP ${s.xp}', style: const TextStyle(color: AppColors.muted, fontSize: 16)),
                            const SizedBox(width: 24),
                            Text('المتبقي للمستوى القادم  XP ${s.xpToNext}', style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 22),
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.gold, width: 4)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('المستوى', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
                        Text('${s.level}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Row(
                children: [
                  Text('91%', style: TextStyle(color: AppColors.cyan, fontSize: 22, fontWeight: FontWeight.w900)),
                  Spacer(),
                  Text('تقدم المستوى', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(value: progress, minHeight: 13, backgroundColor: AppColors.surface, valueColor: const AlwaysStoppedAnimation(AppColors.gold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('الشارات والإنجازات الأكاديمية', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
            SizedBox(width: 12),
            Icon(Icons.workspace_premium_outlined, color: AppColors.gold, size: 34),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < MockData.badges.length; i++) Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _Badge(item: MockData.badges[i], index: i, onTap: () => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(MockData.badges[i].title), content: Text(MockData.badges[i].description), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))]))),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.item, required this.index, required this.onTap});
  final MockBadge item;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = index == 0 ? AppColors.cyan : index == 1 ? const Color(0xFFFF8B00) : AppColors.success;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(25), child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(25), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(width: 76, height: 76, decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(22)), child: Icon(item.icon, color: color, size: 39)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(item.title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(item.description, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.muted, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 29),
        ],
      ),
    ));
  }
}

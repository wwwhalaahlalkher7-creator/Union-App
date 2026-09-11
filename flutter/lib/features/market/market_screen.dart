import 'package:flutter/material.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = ['الكل', 'رسم معماري', 'قياس', 'كهرباء', 'ميكانيكا', 'أخرى'];
    final items = [
      ('لوحة رسم هندسي', 'مستخدمة بحالة جيدة', 'للبيع'),
      ('عدة قياس صغيرة', 'مناسبة للطلاب', 'للتبادل'),
      ('مسطرة T', 'حالة ممتازة', 'للإعارة'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('سوق الأدوات'),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_border_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: const Text('إعلان جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'ابحث عن أداة هندسية...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(onPressed: () {}, icon: const Icon(Icons.tune_rounded)),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ChoiceChip(
                label: Text(categories[index]),
                selected: index == 0,
                onSelected: (_) {},
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Text('أحدث الإعلانات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Text('عرض الكل', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.handyman_outlined, color: cs.primary),
                    ),
                    title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${item.$2}\n${item.$3}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () {},
                  ),
                ),
              )),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('السوق مخصص لطلاب الكلية. سيظهر توثيق الرقم الجامعي عند تفعيل تسجيل الطلاب.')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

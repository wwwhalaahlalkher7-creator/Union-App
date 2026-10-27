import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/authenticated_client.dart';
import '../../shared/widgets/app_card.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  late Future<List<Map<String, dynamic>>> _items = _load();
  String _query = '';
  String _category = '';

  Future<List<Map<String, dynamic>>> _load() async {
    final client = await AuthenticatedClient.create();
    try {
      final result = await client.getJson('/api/v1/market/items', cacheTtl: const Duration(minutes: 3));
      final data = result['data'];
      if (data is! List) return const [];
      return data.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    } finally {
      client.dispose();
    }
  }

  void _refresh() => setState(() => _items = _load());
  String _text(Map<String, dynamic> item, String ar, String en, String fr) {
    final lang = Localizations.localeOf(context).languageCode;
    final localized = lang == 'fr' ? item[fr] : lang == 'en' ? item[en] : item[ar];
    final fallback = item[ar] ?? item[en] ?? item[fr];
    return (localized ?? fallback ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final cs = Theme.of(context).colorScheme;
    String tr(String ar, String en, String fr) => lang == 'fr' ? fr : lang == 'en' ? en : ar;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('market')), actions: [
        IconButton(tooltip: tr('تحديث', 'Refresh', 'Actualiser'), onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _StatePanel(icon: Icons.cloud_off_rounded, text: tr('تعذر تحميل السوق. تحقق من الاتصال ثم أعد المحاولة.', 'Could not load the marketplace. Check your connection and retry.', 'Impossible de charger la boutique. Vérifiez la connexion puis réessayez.'), action: tr('إعادة المحاولة', 'Retry', 'Réessayer'), onTap: _refresh);
          final all = snapshot.data ?? const <Map<String, dynamic>>[];
          final categories = all.map((e) => (e['category'] ?? '').toString()).where((e) => e.isNotEmpty).toSet().toList()..sort();
          final visible = all.where((item) {
            final categoryMatch = _category.isEmpty || item['category'] == _category;
            final needle = _query.trim().toLowerCase();
            final text = '${item['titleAr'] ?? ''} ${item['titleEn'] ?? ''} ${item['descriptionAr'] ?? ''} ${item['descriptionEn'] ?? ''} ${item['category'] ?? ''}'.toLowerCase();
            return categoryMatch && (needle.isEmpty || text.contains(needle));
          }).toList();
          return RefreshIndicator(
            onRefresh: () async { final f = _load(); setState(() => _items = f); await f; },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 28),
              children: [
                Text(tr('أدوات وخدمات هندسية', 'Engineering tools & services', 'Outils et services d’ingénierie'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(tr('عروض منشورة من لوحة التحكم فقط، دون عناصر تجريبية.', 'Only published listings from the dashboard—no demo items.', 'Uniquement les offres publiées depuis le tableau de bord.'), style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('ابحث في السوق', 'Search marketplace', 'Rechercher'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                    Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(tr('الكل', 'All', 'Tout')), selected: _category.isEmpty, onSelected: (_) => setState(() => _category = ''))),
                    for (final category in categories) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(category), selected: _category == category, onSelected: (_) => setState(() => _category = category))),
                  ])),
                ],
                const SizedBox(height: 12),
                if (visible.isEmpty) _StatePanel(icon: Icons.storefront_outlined, text: all.isEmpty ? tr('لا توجد عروض منشورة حاليًا. ستظهر العروض هنا بعد إضافتها من لوحة التحكم.', 'There are no published listings yet. Items will appear here after being added in the dashboard.', 'Aucune offre publiée pour le moment.' ) : tr('لا توجد نتائج مطابقة لبحثك.', 'No listings match your search.', 'Aucun résultat correspondant.'), action: tr('تحديث', 'Refresh', 'Actualiser'), onTap: _refresh),
                for (final item in visible) Padding(padding: const EdgeInsets.only(bottom: 12), child: _MarketItemCard(
                  title: _text(item, 'titleAr', 'titleEn', 'titleFr'),
                  description: _text(item, 'descriptionAr', 'descriptionEn', 'descriptionFr'),
                  price: (item['priceLabel'] ?? '').toString(),
                  category: (item['category'] ?? '').toString(),
                  imageUrl: (item['imageUrl'] ?? '').toString(),
                  department: _text(item, 'departmentNameAr', 'departmentNameEn', 'departmentNameFr'),
                  contactUrl: (item['contactUrl'] ?? '').toString(),
                  contactLabel: tr('التفاصيل / التواصل', 'Details / Contact', 'Détails / Contact'),
                  onContact: () => _open(item['contactUrl']?.toString() ?? '', context, tr('رابط التواصل غير متاح.', 'Contact link is not available.', 'Lien de contact indisponible.')),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(String raw, BuildContext context, String unavailable) async {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || !await canLaunchUrl(uri) || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(unavailable)));
    }
  }
}

class _MarketItemCard extends StatelessWidget {
  const _MarketItemCard({required this.title, required this.description, required this.price, required this.category, required this.imageUrl, required this.department, required this.contactUrl, required this.contactLabel, required this.onContact});
  final String title, description, price, category, imageUrl, department, contactUrl, contactLabel;
  final VoidCallback onContact;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (imageUrl.startsWith('https://')) ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 7, child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder(cs)))),
      if (!imageUrl.startsWith('https://')) _imagePlaceholder(cs),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
        if (price.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Text(price, style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800))),
      ]),
      if (category.isNotEmpty || department.isNotEmpty) ...[const SizedBox(height: 6), Text([category, department].where((x) => x.isNotEmpty).join(' • '), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))],
      if (description.isNotEmpty) ...[const SizedBox(height: 8), Text(description, style: const TextStyle(height: 1.45))],
      if (contactUrl.isNotEmpty) ...[const SizedBox(height: 12), Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton.icon(onPressed: onContact, icon: const Icon(Icons.open_in_new_rounded, size: 18), label: Text(contactLabel)))],
    ]));
  }
  Widget _imagePlaceholder(ColorScheme cs) => Container(height: 88, width: double.infinity, decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: .5), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.handyman_rounded, size: 34, color: cs.primary));
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.icon, required this.text, required this.action, required this.onTap});
  final IconData icon; final String text, action; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 18), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 14), Text(text, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onTap, icon: const Icon(Icons.refresh_rounded), label: Text(action))]));
}

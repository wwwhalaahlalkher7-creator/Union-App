import 'package:flutter/material.dart';
import '../../core/di/app_dependencies.dart';
import '../../data/repositories/downloaded_materials_store.dart';
import '../../shared/widgets/app_card.dart';
import 'materials_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DownloadedMaterialsStore _store = DownloadedMaterialsStore();
  List<DownloadedMaterial> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await AppDependencies.instance.authStorage.profile;
    final ownerKey = (profile?['studentId'] ?? profile?['studentNumber'] ?? 'guest').toString();
    final items = await _store.list(ownerKey: ownerKey);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _open(DownloadedMaterial item) async {
    final file = item.file;
    if (!await _store.isValidPdfFile(file)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملف غير موجود على الجهاز. أعد تنزيله من صفحة المواد.')),
        );
      }
      await _load();
      return;
    }
    if (!mounted) return;
    final token = (await AppDependencies.instance.authStorage.accessToken) ?? '';
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PdfMaterialViewerScreen(
        title: item.title,
        materialId: item.materialId,
        url: null,
        accessToken: token,
        localFile: file,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 30),
        children: [
          Text('التنزيلات', textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('ملفاتك المحفوظة للقراءة دون اتصال. تُحفظ نسخة عامة في Download/TRINEX على أجهزة Android المدعومة.',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            AppCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.download_for_offline_outlined, size: 36),
              const SizedBox(height: 8),
              const Text('لا توجد ملفات منزلة حتى الآن.', textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('افتح صفحة المواد واضغط زر التنزيل بجوار الشيت الذي تحتاجه.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]))
          else
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: AppCard(
                  onTap: () => _open(item),
                  child: Row(children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('محفوظ للقراءة دون اتصال',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ])),
                    const SizedBox(width: 8),
                    const Icon(Icons.open_in_new_rounded),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}

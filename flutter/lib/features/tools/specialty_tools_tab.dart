part of 'tools_screen.dart';

class _SpecialtyToolsTab extends StatelessWidget {
  const _SpecialtyToolsTab();

  Future<void> _openTool(BuildContext context, String title, String description) async {
    final first = TextEditingController();
    final second = TextEditingController();
    String result = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(description),
            const SizedBox(height: 12),
            TextField(controller: first, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'القيمة الأولى')),
            const SizedBox(height: 8),
            if (!title.contains('الأنظمة العددية')) TextField(controller: second, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'القيمة الثانية')),
            if (result.isNotEmpty) ...[const SizedBox(height: 14), SelectableText(result, style: const TextStyle(fontWeight: FontWeight.w800))],
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
            FilledButton(onPressed: () {
              final a = double.tryParse(first.text.trim());
              final b = double.tryParse(second.text.trim());
              if (title.contains('الأنظمة العددية')) {
                final n = int.tryParse(first.text.trim());
                setDialogState(() => result = n == null ? 'أدخل عددًا صحيحًا صالحًا.' : '$n (عشري) = ${n.toRadixString(2)} (ثنائي)\n${n.toRadixString(16).toUpperCase()} (سداسي عشر)');
                return;
              }
              if (a == null || b == null) { setDialogState(() => result = 'أدخل قيمتين رقميتين صحيحتين.'); return; }
              String output;
              if (title.contains('قانون أوم')) output = b == 0 ? 'التيار لا يمكن أن يكون صفرًا.' : 'المقاومة R = ${(a / b).toStringAsFixed(4)} Ω';
              else if (title == 'القدرة الكهربائية') output = 'القدرة P = ${(a * b).toStringAsFixed(4)} W';
              else if (title == 'حاسبة الميل') output = b == 0 ? 'المسافة الأفقية لا يمكن أن تكون صفرًا.' : 'الميل = ${(a / b * 100).toStringAsFixed(2)}%';
              else if (title == 'مقاومات التوالي والتوازي') output = 'التوالي: ${(a + b).toStringAsFixed(4)} Ω\nالتوازي: ${(a + b) == 0 ? 'غير معرّف' : (a * b / (a + b)).toStringAsFixed(4)} Ω';
              else if (title == 'مقياس الرسم') output = 'الطول الحقيقي = ${(a * b).toStringAsFixed(4)} (بنفس وحدة القياس).';
              else if (title == 'حجم الخرسانة') output = 'الحجم = ${(a * b).toStringAsFixed(4)} م³ (مساحة المقطع × الارتفاع).';
              else output = 'الناتج = ${(a * b).toStringAsFixed(4)}';
              setDialogState(() => result = output);
            }, child: const Text('احسب')),
          ],
        ),
      ),
    );
    first.dispose();
    second.dispose();
  }


  Future<String> _department() async {
    final deps = AppDependencies.instance;
    if (!await deps.authStorage.isLoggedIn) return 'general';
    final profile = await deps.student.profile();
    final value = '${profile.departmentName ?? ''} ${profile.departmentId}'.toLowerCase();
    if (value.contains('civil') || value.contains('مدني') || value.contains('مدنية')) return 'civil';
    if (value.contains('elect') || value.contains('كهرب') || value.contains('الكترون') || value.contains('إلكترون')) return 'electrical';
    if (value.contains('architect') || value.contains('عمارة') || value.contains('معمار')) return 'architecture';
    if (value.contains('computer') || value.contains('حاسوب') || value.contains('برمج')) return 'computing';
    return 'general';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _department(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final dept = snapshot.data ?? 'general';
        final items = switch (dept) {
          'electrical' => <(String, String, IconData)>[
            ('قانون أوم', 'احسب الجهد أو التيار أو المقاومة باستخدام V = I × R.', Icons.bolt_rounded),
            ('القدرة الكهربائية', 'احسب القدرة من P = V × I.', Icons.electric_meter_rounded),
            ('مقاومات التوالي والتوازي', 'راجع القيم المكافئة للمقاومات في الدوائر.', Icons.memory_rounded),
            ('تحويل الوحدات الكهربائية', 'تحويلات التيار والجهد والقدرة والمقاومة.', Icons.swap_horiz_rounded),
          ],
          'civil' => <(String, String, IconData)>[
            ('حجم الخرسانة', 'حساب حجم البلاطة أو الكمرة أو القاعدة من الأبعاد.', Icons.view_in_ar_rounded),
            ('تحويل الإجهاد', 'تحويل Pa و kPa و MPa و psi.', Icons.compress_rounded),
            ('مساحة ومحيط المقاطع', 'حسابات أولية للمستطيل والدائرة والمثلث.', Icons.square_foot_rounded),
            ('حاسبة الميل', 'حساب الميل كنسبة مئوية من الارتفاع والمسافة الأفقية.', Icons.trending_up_rounded),
          ],
          'architecture' => <(String, String, IconData)>[
            ('مقياس الرسم', 'تحويل القياس على المخطط إلى قياس حقيقي والعكس.', Icons.architecture_rounded),
            ('مساحة الغرف', 'حساب المساحة والمحيط للأشكال الأساسية.', Icons.crop_square_rounded),
            ('تحويل الوحدات', 'تحويل mm و cm و m و ft و inch.', Icons.straighten_rounded),
            ('نسبة الأبعاد', 'مقارنة أبعاد المخطط مع الأبعاد الفعلية.', Icons.aspect_ratio_rounded),
          ],
          'computing' => <(String, String, IconData)>[
            ('تحويل الأنظمة العددية', 'تحويل الأعداد بين الثنائي والعشري والسداسي عشر.', Icons.numbers_rounded),
            ('حاسبة البتات والبايتات', 'تحويل bit و byte و KB و MB و GB.', Icons.memory_rounded),
            ('قانون أوم للإلكترونيات', 'حسابات سريعة للجهد والتيار والمقاومة.', Icons.electrical_services_rounded),
            ('تحويل الوحدات', 'أدوات عامة للقياسات الهندسية.', Icons.swap_horiz_rounded),
          ],
          _ => <(String, String, IconData)>[
            ('مقياس الرسم', 'مفيد لطلاب العمارة والرسم الهندسي.', Icons.architecture_rounded),
            ('حجم الخرسانة', 'حساب أولي للحجم من الأبعاد المدخلة.', Icons.view_in_ar_rounded),
            ('قانون أوم', 'أداة أساسية لدوائر الكهرباء والإلكترونيات.', Icons.bolt_rounded),
            ('تحويل الأنظمة العددية', 'للطلاب في الحوسبة والإلكترونيات الرقمية.', Icons.numbers_rounded),
          ],
        };
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(dept == 'general' ? 'أدوات حسب التخصص' : 'أدوات تخصصك', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(dept == 'general' ? 'سجّل الدخول لعرض أدوات أكثر ملاءمة لقسمك. الأدوات العامة متاحة هنا أيضًا.' : 'اقتراحات عملية لقسمك. ستضاف الحاسبات المتخصصة تباعًا.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: AppCard(
                  padding: const EdgeInsets.all(15),
                  onTap: () => _openTool(context, item.$1, item.$2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(item.$3, color: Theme.of(context).colorScheme.primary, size: 26),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(item.$2, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            Text('تنبيه: نتائج هذه الأدوات للتعلم والتقدير الأولي، ولا تُغني عن مراجعة المعايير الهندسية أو المختصين في القرارات التنفيذية.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        );
      },
    );
  }
}

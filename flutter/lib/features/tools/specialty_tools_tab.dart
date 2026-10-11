part of 'tools_screen.dart';

class _SpecialtyToolsTab extends StatelessWidget {
  const _SpecialtyToolsTab();

  Future<void> _openTool(BuildContext context, String title, String description) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final third = TextEditingController();
    String result = '';
    String fromUnit = 'm';
    String toUnit = 'cm';
    final needsThird = title == 'حجم الخرسانة';
    final unitOptions = switch (title) {
      'تحويل الإجهاد' => const <String>['Pa', 'kPa', 'MPa', 'psi'],
      'تحويل الوحدات' => const <String>['mm', 'cm', 'm', 'km', 'in', 'ft'],
      'تحويل وحدات التيار' => const <String>['mA', 'A', 'kA'],
      'حاسبة البتات والبايتات' => const <String>['bit', 'B', 'KB', 'MB', 'GB'],
      _ => const <String>['m', 'cm', 'mm', 'km'],
    };
    if (!unitOptions.contains(fromUnit)) {
      fromUnit = unitOptions.first;
    }
    if (!unitOptions.contains(toUnit) || fromUnit == toUnit) {
      toUnit = unitOptions.length > 1 ? unitOptions[1] : unitOptions.first;
    }

    String inputLabel(int index) => switch (title) {
      'قانون أوم' || 'قانون أوم للإلكترونيات' || 'القدرة الكهربائية' => index == 0 ? 'الجهد (V)' : 'التيار (A)',
      'مقاومات التوالي والتوازي' => index == 0 ? 'المقاومة الأولى (Ω)' : 'المقاومة الثانية (Ω)',
      'حجم الخرسانة' => ['الطول (م)', 'العرض (م)', 'الارتفاع (م)'][index],
      'مساحة ومحيط المقاطع' || 'مساحة الغرف' => index == 0 ? 'الطول (م)' : 'العرض (م)',
      'حاسبة الميل' => index == 0 ? 'الارتفاع' : 'المسافة الأفقية',
      'مقياس الرسم' => index == 0 ? 'الطول على الرسم' : 'مقام المقياس (مثل 100 في 1:100)',
      'نسبة الأبعاد' => index == 0 ? 'العرض' : 'الارتفاع',
      'تحويل الإجهاد' || 'تحويل الوحدات' || 'تحويل وحدات التيار' || 'حاسبة البتات والبايتات' => 'القيمة',
      _ => index == 0 ? 'القيمة الأولى' : 'القيمة الثانية',
    };

    final usesUnitPicker = title == 'تحويل الإجهاد' || title == 'تحويل الوحدات' || title == 'تحويل وحدات التيار' || title == 'حاسبة البتات والبايتات';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(description),
            const SizedBox(height: 12),
            TextField(controller: first, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: inputLabel(0))),
            if (!title.contains('الأنظمة العددية')) ...[
              const SizedBox(height: 8),
              if (!usesUnitPicker) TextField(controller: second, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: inputLabel(1))),
              if (needsThird) ...[
                const SizedBox(height: 8),
                TextField(controller: third, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: inputLabel(2))),
              ],
              if (usesUnitPicker) ...[
                DropdownButtonFormField<String>(initialValue: fromUnit, decoration: const InputDecoration(labelText: 'من الوحدة'), items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) { if (v != null) { setDialogState(() { fromUnit = v; if (toUnit == fromUnit) { toUnit = unitOptions.firstWhere((u) => u != fromUnit, orElse: () => fromUnit); } }); } }),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(initialValue: toUnit, decoration: const InputDecoration(labelText: 'إلى الوحدة'), items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) { if (v != null) { setDialogState(() => toUnit = v); } }),
              ],
            ],
            if (result.isNotEmpty) ...[const SizedBox(height: 14), SelectableText(result, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.5))],
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
            FilledButton(onPressed: () {
              final a = double.tryParse(first.text.trim().replaceAll(',', '.'));
              final b = double.tryParse(second.text.trim().replaceAll(',', '.'));
              final c = double.tryParse(third.text.trim().replaceAll(',', '.'));
              String output;
              if (title.contains('الأنظمة العددية')) {
                final n = int.tryParse(first.text.trim());
                output = n == null ? 'أدخل عددًا صحيحًا صالحًا.' : '$n (عشري) = ${n.toRadixString(2)} (ثنائي)\n${n.toRadixString(16).toUpperCase()} (سداسي عشر)';
              } else if (a == null || !a.isFinite) {
                output = 'أدخل قيمة رقمية صحيحة.';
              } else if (usesUnitPicker) {
                if (title == 'تحويل الإجهاد') {
                  output = '${EngineeringCalculations.convertStress(a, fromUnit, toUnit).toStringAsPrecision(7)} $toUnit';
                } else if (title == 'حاسبة البتات والبايتات') {
                  output = '${EngineeringCalculations.convertDataSize(a, fromUnit, toUnit).toStringAsPrecision(7)} $toUnit (على أساس 1000)';
                } else if (title == 'تحويل وحدات التيار') {
                  output = '${EngineeringCalculations.convertCurrent(a, fromUnit, toUnit).toStringAsPrecision(7)} $toUnit';
                } else {
                  output = '${EngineeringCalculations.convertLength(a, fromUnit, toUnit).toStringAsPrecision(7)} $toUnit';
                }
              } else if (b == null || !b.isFinite) {
                output = 'أدخل قيمة ثانية صحيحة.';
              } else if (title == 'قانون أوم' || title == 'قانون أوم للإلكترونيات') {
                output = b == 0 ? 'التيار لا يمكن أن يكون صفرًا.' : 'المقاومة R = ${EngineeringCalculations.resistanceFromVoltageCurrent(a, b).toStringAsPrecision(7)} Ω';
              } else if (title == 'القدرة الكهربائية') {
                output = 'القدرة P = ${EngineeringCalculations.electricalPower(a, b).toStringAsPrecision(7)} W';
              } else if (title == 'مقاومات التوالي والتوازي') {
                if (a < 0 || b < 0) { output = 'قيم المقاومة لا يمكن أن تكون سالبة.'; }
                else { final sum = EngineeringCalculations.seriesResistance(a, b); output = 'التوالي: ${sum.toStringAsPrecision(7)} Ω\nالتوازي: ${sum == 0 ? 'غير معرّف' : EngineeringCalculations.parallelResistance(a, b).toStringAsPrecision(7)} Ω'; }
              } else if (title == 'حجم الخرسانة') {
                if (c == null || !c.isFinite || a < 0 || b < 0 || c < 0) {
                  output = 'أدخل ثلاثة أبعاد موجبة أو صفرًا.';
                } else {
                  output = 'الحجم = ${EngineeringCalculations.concreteVolume(a, b, c).toStringAsPrecision(7)} م³';
                }
              } else if (title == 'مساحة ومحيط المقاطع' || title == 'مساحة الغرف') {
                if (a < 0 || b < 0) {
                  output = 'الأبعاد لا يمكن أن تكون سالبة.';
                } else {
                  final shape = EngineeringCalculations.rectangle(a, b);
                  output = 'المساحة = ${shape.area.toStringAsPrecision(7)} م²\nالمحيط = ${shape.perimeter.toStringAsPrecision(7)} م';
                }
              } else if (title == 'حاسبة الميل') {
                output = b == 0 ? 'المسافة الأفقية لا يمكن أن تكون صفرًا.' : 'الميل = ${EngineeringCalculations.slopePercent(a, b).toStringAsPrecision(6)}%';
              } else if (title == 'مقياس الرسم') {
                if (b <= 0) {
                  output = 'مقام المقياس يجب أن يكون أكبر من صفر.';
                } else {
                  output = 'الطول الحقيقي = ${EngineeringCalculations.scaledLength(a, b).toStringAsPrecision(7)} (بنفس وحدة الرسم)';
                }
              } else if (title == 'نسبة الأبعاد') {
                output = b == 0 ? 'الارتفاع لا يمكن أن يكون صفرًا.' : 'نسبة العرض إلى الارتفاع = ${EngineeringCalculations.aspectRatio(a, b).toStringAsPrecision(6)} : 1';
              } else {
                output = 'الناتج = ${(a * b).toStringAsPrecision(7)}';
              }
              setDialogState(() => result = output);
            }, child: const Text('احسب')),
          ],
        ),
      ),
    );
    first.dispose();
    second.dispose();
    third.dispose();
  }


  Future<String> _department() async {
    final deps = AppDependencies.instance;
    if (!await deps.authStorage.isLoggedIn) {
      return 'general';
    }
    final profile = await deps.student.profile();
    final value = '${profile.departmentName ?? ''} ${profile.departmentId}'.toLowerCase();
    if (value.contains('civil') || value.contains('مدني') || value.contains('مدنية')) {
      return 'civil';
    }
    if (value.contains('elect') || value.contains('كهرب') || value.contains('الكترون') || value.contains('إلكترون')) {
      return 'electrical';
    }
    if (value.contains('architect') || value.contains('عمارة') || value.contains('معمار')) {
      return 'architecture';
    }
    if (value.contains('computer') || value.contains('حاسوب') || value.contains('برمج')) {
      return 'computing';
    }
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
            ('قانون أوم', 'أدخل الجهد V والتيار I لحساب المقاومة R = V ÷ I.', Icons.bolt_rounded),
            ('القدرة الكهربائية', 'احسب القدرة من P = V × I.', Icons.electric_meter_rounded),
            ('مقاومات التوالي والتوازي', 'راجع القيم المكافئة للمقاومات في الدوائر.', Icons.memory_rounded),
            ('تحويل وحدات التيار', 'تحويل mA و A و kA مع الحفاظ على وحدة القياس نفسها.', Icons.swap_horiz_rounded),
          ],
          'civil' => <(String, String, IconData)>[
            ('حجم الخرسانة', 'حساب حجم البلاطة أو الكمرة أو القاعدة من الأبعاد.', Icons.view_in_ar_rounded),
            ('تحويل الإجهاد', 'تحويل Pa و kPa و MPa و psi.', Icons.compress_rounded),
            ('مساحة ومحيط المقاطع', 'حساب المساحة والمحيط لمقطع مستطيل من الطول والعرض.', Icons.square_foot_rounded),
            ('حاسبة الميل', 'حساب الميل كنسبة مئوية من الارتفاع والمسافة الأفقية.', Icons.trending_up_rounded),
          ],
          'architecture' => <(String, String, IconData)>[
            ('مقياس الرسم', 'احسب الطول الحقيقي بضرب طول الرسم في مقام المقياس، مثل 1:100.', Icons.architecture_rounded),
            ('مساحة الغرف', 'حساب مساحة ومحيط غرفة مستطيلة من الطول والعرض.', Icons.crop_square_rounded),
            ('تحويل الوحدات', 'تحويل mm و cm و m و ft و inch.', Icons.straighten_rounded),
            ('نسبة الأبعاد', 'مقارنة أبعاد المخطط مع الأبعاد الفعلية.', Icons.aspect_ratio_rounded),
          ],
          'computing' => <(String, String, IconData)>[
            ('تحويل الأنظمة العددية', 'تحويل الأعداد بين الثنائي والعشري والسداسي عشر.', Icons.numbers_rounded),
            ('حاسبة البتات والبايتات', 'تحويل bit و byte و KB و MB و GB.', Icons.memory_rounded),
            ('قانون أوم للإلكترونيات', 'أدخل الجهد V والتيار I لحساب المقاومة R = V ÷ I.', Icons.electrical_services_rounded),
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

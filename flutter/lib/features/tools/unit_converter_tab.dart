part of 'tools_screen.dart';

class _UnitConverterTab extends StatefulWidget {
  const _UnitConverterTab();

  @override
  State<_UnitConverterTab> createState() => _UnitConverterTabState();
}

class _UnitConverterTabState extends State<_UnitConverterTab> {
  final _inputController = TextEditingController(text: '1');
  String _category = 'Length';

  String _categoryLabel(AppLocalizations l10n, String category) => switch (category) {
    'Length' => l10n.t('unitLength'),
    'Force' => l10n.t('unitForce'),
    'Pressure / Stress' => l10n.t('unitPressureStress'),
    'Energy / Power' => l10n.t('unitEnergyPower'),
    _ => category,
  };
  String _fromUnit = 'm';
  String _toUnit = 'cm';
  double _result = 100.0;

  final Map<String, Map<String, double>> _conversionFactors = {
    'Length': {
      'm': 1.0,
      'cm': 0.01,
      'mm': 0.001,
      'km': 1000.0,
      'inch': 0.0254,
      'ft': 0.3048,
    },
    'Force': {
      'N': 1.0,
      'kN': 1000.0,
      'lbf': 4.4482216153,
    },
    'Pressure / Stress': {
      'Pa': 1.0,
      'kPa': 1000.0,
      'MPa': 1000000.0,
      'bar': 100000.0,
      'psi': 6894.757293168,
    },
    'Energy / Power': {
      'J': 1.0,
      'kJ': 1000.0,
      'cal': 4.184,
      'kcal': 4184.0,
      'Wh': 3600.0,
      'kWh': 3600000.0,
      'hp': 745.7,
    },
  };

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final val = double.tryParse(_inputController.text) ?? 0.0;
    final factors = _conversionFactors[_category]!;
    final fromFactor = factors[_fromUnit] ?? 1.0;
    final toFactor = factors[_toUnit] ?? 1.0;

    final inBase = val * fromFactor;
    setState(() {
      _result = inBase / toFactor;
    });
  }

  void _onCategoryChanged(String newCat) {
    setState(() {
      _category = newCat;
      final units = _conversionFactors[newCat]!.keys.toList();
      _fromUnit = units[0];
      _toUnit = units.length > 1 ? units[1] : units[0];
    });
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final units = _conversionFactors[_category]!.keys.toList();

    return ListView(
      padding: const EdgeInsets.all(14.72),
      children: [
        // Category Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _conversionFactors.keys.map((cat) {
              final selected = cat == _category;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 7.36),
                child: FilterChip(
                  label: Text(_categoryLabel(l10n, cat)),
                  selected: selected,
                  onSelected: (_) => _onCategoryChanged(cat),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        AppCard(
          padding: const EdgeInsets.all(18.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _inputController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _recalculate(),
                decoration: InputDecoration(
                  labelText: l10n.t('value'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.8)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _fromUnit,
                      decoration: InputDecoration(
                        labelText: l10n.t('from'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.8)),
                      ),
                      items: units
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _fromUnit = val;
                          _recalculate();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onPressed: () {
                      final temp = _fromUnit;
                      setState(() {
                        _fromUnit = _toUnit;
                        _toUnit = temp;
                      });
                      _recalculate();
                    },
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _toUnit,
                      decoration: InputDecoration(
                        labelText: l10n.t('to'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.8)),
                      ),
                      items: units
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _toUnit = val;
                          _recalculate();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Result Display
              Container(
                padding: const EdgeInsets.all(14.72),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14.4),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.t('result'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      '${_result.toStringAsPrecision(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} $_toUnit',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// 2. GPA Calculator Tab
// -------------------------------------------------------------

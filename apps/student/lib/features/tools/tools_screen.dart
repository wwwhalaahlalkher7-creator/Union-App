import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/app_card.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('toolsTitle')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.straighten_rounded), text: l10n.t('unitConverter')),
            Tab(icon: const Icon(Icons.calculate_rounded), text: l10n.t('gpaCalculator')),
            Tab(icon: const Icon(Icons.palette_outlined), text: l10n.t('resistorCalculator')),
            Tab(icon: const Icon(Icons.menu_book_rounded), text: l10n.t('engineeringReferences')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UnitConverterTab(),
          _GpaCalculatorTab(),
          _ResistorCalculatorTab(),
          _EngineeringReferencesTab(),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. Unit Converter Tab
// -------------------------------------------------------------
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
class _CourseEntry {
  _CourseEntry({required this.credits, required this.gradePoints});
  double credits;
  double gradePoints;
}

class _GpaCalculatorTab extends StatefulWidget {
  const _GpaCalculatorTab();

  @override
  State<_GpaCalculatorTab> createState() => _GpaCalculatorTabState();
}

class _GpaCalculatorTabState extends State<_GpaCalculatorTab> {
  final List<_CourseEntry> _courses = [
    _CourseEntry(credits: 3, gradePoints: 4.0),
    _CourseEntry(credits: 3, gradePoints: 3.5),
    _CourseEntry(credits: 2, gradePoints: 3.0),
    _CourseEntry(credits: 3, gradePoints: 3.7),
  ];

  static const Map<String, double> _gradeScale = {
    'A+ (4.0)': 4.0,
    'A (3.75)': 3.75,
    'B+ (3.5)': 3.5,
    'B (3.0)': 3.0,
    'C+ (2.5)': 2.5,
    'C (2.0)': 2.0,
    'D+ (1.5)': 1.5,
    'D (1.0)': 1.0,
    'F (0.0)': 0.0,
  };

  double get _calculatedGpa {
    double totalPoints = 0;
    double totalCredits = 0;
    for (final c in _courses) {
      totalPoints += c.gradePoints * c.credits;
      totalCredits += c.credits;
    }
    if (totalCredits == 0) return 0.0;
    return totalPoints / totalCredits;
  }

  double get _totalCredits {
    return _courses.fold(0.0, (sum, c) => sum + c.credits);
  }

  String _standingText(AppLocalizations l10n, double gpa) {
    if (gpa >= 3.5) return l10n.t('standingExcellent');
    if (gpa >= 3.0) return l10n.t('standingVeryGood');
    if (gpa >= 2.5) return l10n.t('standingGood');
    if (gpa >= 2.0) return l10n.t('standingPass');
    return l10n.t('standingWarning');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final gpa = _calculatedGpa;

    return ListView(
      padding: const EdgeInsets.all(14.72),
      children: [
        // Live GPA Badge
        AppCard(
          padding: const EdgeInsets.all(16.56),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('gpaResult', {'gpa': gpa.toStringAsFixed(2)}),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.t('credits')}: ${_totalCredits.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.72, vertical: 7.36),
                decoration: BoxDecoration(
                  color: (gpa >= 3.0 ? Colors.green : (gpa >= 2.0 ? Colors.orange : Colors.red))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14.4),
                ),
                child: Text(
                  _standingText(l10n, gpa),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: gpa >= 3.0 ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Course rows
        ...List.generate(_courses.length, (index) {
          final course = _courses[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12.88, vertical: 9.2),
              child: Row(
                children: [
                  Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  // Credits selector
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: course.credits,
                      decoration: InputDecoration(
                        labelText: l10n.t('credits'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 9.2, vertical: 7.36),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      items: [1.0, 2.0, 3.0, 4.0, 5.0]
                          .map((c) => DropdownMenuItem(value: c, child: Text('${c.toInt()}')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => course.credits = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Grade selector
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<double>(
                      initialValue: course.gradePoints,
                      decoration: InputDecoration(
                        labelText: l10n.t('grade'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 9.2, vertical: 7.36),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      items: _gradeScale.entries
                          .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => course.gradePoints = val);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                    onPressed: _courses.length > 1
                        ? () => setState(() => _courses.removeAt(index))
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () {
            setState(() {
              _courses.add(_CourseEntry(credits: 3, gradePoints: 3.5));
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.t('addCourse')),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// 3. Resistor Color Decoder Tab
// -------------------------------------------------------------
class _ResistorCalculatorTab extends StatefulWidget {
  const _ResistorCalculatorTab();

  @override
  State<_ResistorCalculatorTab> createState() => _ResistorCalculatorTabState();
}

class _ResistorCalculatorTabState extends State<_ResistorCalculatorTab> {
  int _band1 = 1; // Brown
  int _band2 = 0; // Black
  int _multiplierIndex = 2; // Red (10^2)
  double _tolerance = 5.0; // Gold (+/- 5%)

  static const List<Map<String, dynamic>> _colors = [
    {'name': 'resistorBlack', 'color': Colors.black, 'val': 0},
    {'name': 'resistorBrown', 'color': Color(0xFF8D6E63), 'val': 1},
    {'name': 'resistorRed', 'color': Colors.red, 'val': 2},
    {'name': 'resistorOrange', 'color': Colors.orange, 'val': 3},
    {'name': 'resistorYellow', 'color': Colors.amber, 'val': 4},
    {'name': 'resistorGreen', 'color': Colors.green, 'val': 5},
    {'name': 'resistorBlue', 'color': Colors.blue, 'val': 6},
    {'name': 'resistorViolet', 'color': Colors.purple, 'val': 7},
    {'name': 'resistorGray', 'color': Colors.grey, 'val': 8},
    {'name': 'resistorWhite', 'color': Colors.white, 'val': 9},
  ];

  String get _resistanceString {
    final base = (_band1 * 10) + _band2;
    final multiplier = [
      1,
      10,
      100,
      1000,
      10000,
      100000,
      1000000,
      10000000,
      100000000,
      1000000000
    ][_multiplierIndex];
    final total = base * multiplier;

    if (total >= 1000000) {
      return '${(total / 1000000).toStringAsFixed(1)} MΩ (±$_tolerance%)';
    } else if (total >= 1000) {
      return '${(total / 1000).toStringAsFixed(1)} kΩ (±$_tolerance%)';
    } else {
      return '$total Ω (±$_tolerance%)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(14.72),
      children: [
        // Resistor Visual Simulation
        AppCard(
          padding: const EdgeInsets.all(22.08),
          child: Column(
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E5D8),
                  borderRadius: BorderRadius.circular(25.2),
                  border: Border.all(color: const Color(0xFFD4C2AB), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stripeWidget(_colors[_band1]['color'] as Color),
                    _stripeWidget(_colors[_band2]['color'] as Color),
                    _stripeWidget(_colors[_multiplierIndex]['color'] as Color),
                    const SizedBox(width: 16),
                    _stripeWidget(_tolerance == 5.0 ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _resistanceString,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Band 1
        _buildColorDropdown(
          label: l10n.t('resistorBand1'),
          value: _band1,
          onChanged: (v) => setState(() => _band1 = v),
        ),
        const SizedBox(height: 12),

        // Band 2
        _buildColorDropdown(
          label: l10n.t('resistorBand2'),
          value: _band2,
          onChanged: (v) => setState(() => _band2 = v),
        ),
        const SizedBox(height: 12),

        // Multiplier
        _buildColorDropdown(
          label: l10n.t('resistorMultiplier'),
          value: _multiplierIndex,
          onChanged: (v) => setState(() => _multiplierIndex = v),
        ),
        const SizedBox(height: 12),

        // Tolerance
        AppCard(
          padding: const EdgeInsets.all(11.04),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.t('tolerance'), style: const TextStyle(fontWeight: FontWeight.w600)),
              SegmentedButton<double>(
                segments: [
                  ButtonSegment(value: 5.0, label: Text(l10n.t('goldTolerance'))),
                  ButtonSegment(value: 10.0, label: Text(l10n.t('silverTolerance'))),
                ],
                selected: {_tolerance},
                onSelectionChanged: (set) => setState(() => _tolerance = set.first),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stripeWidget(Color color) {
    return Container(
      width: 14,
      height: 52,
      color: color,
    );
  }

  Widget _buildColorDropdown({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final l10n = AppLocalizations.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12.88, vertical: 7.36),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
        items: List.generate(_colors.length, (i) {
          final c = _colors[i];
          return DropdownMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c['color'] as Color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 10),
                Text(l10n.t(c['name'] as String)),
              ],
            ),
          );
        }),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. Engineering References Tab
// -------------------------------------------------------------
class _EngineeringReferencesTab extends StatelessWidget {
  const _EngineeringReferencesTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final references = [
      {'title': l10n.t('refOhmTitle'), 'formula': 'V = I × R  |  P = V × I = I² × R', 'desc': l10n.t('refOhmDesc')},
      {'title': l10n.t('refBendingTitle'), 'formula': 'σ = (M × y) / I', 'desc': l10n.t('refBendingDesc')},
      {'title': l10n.t('refHookeTitle'), 'formula': 'σ = E × ε', 'desc': l10n.t('refHookeDesc')},
      {'title': l10n.t('refBernoulliTitle'), 'formula': 'P + 0.5 × ρ × v² + ρ × g × h = constant', 'desc': l10n.t('refBernoulliDesc')},
      {'title': l10n.t('refPaperSizesTitle'), 'formula': 'A0: 841×1189 mm | A1: 594×841 mm | A2: 420×594 mm | A3: 297×420 mm', 'desc': l10n.t('refPaperSizesDesc')},
      {'title': l10n.t('refScalesTitle'), 'formula': '1:100 | 1:50 | 1:20 | 1:10', 'desc': l10n.t('refScalesDesc')},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(14.72),
      itemCount: references.length,
      itemBuilder: (context, index) {
        final ref = references[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(14.72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref['title']!,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 11.04, vertical: 7.36),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(7.2),
                  ),
                  child: Text(
                    ref['formula']!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ref['desc']!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

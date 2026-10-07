part of 'tools_screen.dart';

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

part of 'tools_screen.dart';

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

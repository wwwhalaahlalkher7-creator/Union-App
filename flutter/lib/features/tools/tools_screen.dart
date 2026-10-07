import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/app_card.dart';

part 'unit_converter_tab.dart';
part 'gpa_calculator_tab.dart';
part 'resistor_calculator_tab.dart';
part 'engineering_references_tab.dart';

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

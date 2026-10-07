part of 'tools_screen.dart';

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
      {'title': l10n.t('refStressStrainTitle'), 'formula': 'σ = E × ε', 'desc': l10n.t('refStressStrainDesc')},
      {'title': l10n.t('refShearStressTitle'), 'formula': 'τ = F / A', 'desc': l10n.t('refShearStressDesc')},
      {'title': l10n.t('refPowerMechanicalTitle'), 'formula': 'P = F × v  |  P = T × ω', 'desc': l10n.t('refPowerMechanicalDesc')},
      {'title': l10n.t('refKineticEnergyTitle'), 'formula': 'Eₖ = ½ × m × v²', 'desc': l10n.t('refKineticEnergyDesc')},
      {'title': l10n.t('refPotentialEnergyTitle'), 'formula': 'Eₚ = m × g × h', 'desc': l10n.t('refPotentialEnergyDesc')},
      {'title': l10n.t('refContinuityTitle'), 'formula': 'A₁v₁ = A₂v₂', 'desc': l10n.t('refContinuityDesc')},
      {'title': l10n.t('refHeatTitle'), 'formula': 'Q = m × c × ΔT', 'desc': l10n.t('refHeatDesc')},
      {'title': l10n.t('refThermalExpansionTitle'), 'formula': 'ΔL = α × L₀ × ΔT', 'desc': l10n.t('refThermalExpansionDesc')},
      {'title': l10n.t('refDensityTitle'), 'formula': 'ρ = m / V', 'desc': l10n.t('refDensityDesc')},
      {'title': l10n.t('refCircleAreaTitle'), 'formula': 'A = π × r²', 'desc': l10n.t('refCircleAreaDesc')},
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

import 'package:flutter/material.dart';

import 'eino_orb.dart';

enum EinoMood {
  calm,
  happy,
  curious,
  focused,
  surprised,
  confused,
  pouting,
  concerned,
  proud,
  thinking,
  talking;

  // Backward-compatibility aliases for existing callers.
  static const EinoMood idle = EinoMood.calm;
  static const EinoMood error = EinoMood.concerned;
}

/// Backward-compatible Eino visual API. The old character illustration has
/// been replaced by the lightweight glass-core orb used across TRINEX.
class EinoFace extends StatelessWidget {
  const EinoFace({
    super.key,
    this.size = 86,
    this.talking = false,
    this.mood = EinoMood.calm,
    this.accentColor,
    this.showAura = true,
  });

  final double size;
  final bool talking;
  final EinoMood mood;
  final Color? accentColor;
  final bool showAura;

  @override
  Widget build(BuildContext context) {
    final themeAccent = accentColor ?? Theme.of(context).colorScheme.primary;
    final moodAccent = switch (mood) {
      EinoMood.happy || EinoMood.proud => Color.lerp(themeAccent, Colors.white, 0.18)!,
      EinoMood.curious || EinoMood.surprised => Color.lerp(themeAccent, Colors.cyan, 0.22)!,
      EinoMood.focused || EinoMood.thinking || EinoMood.talking => Color.lerp(themeAccent, Colors.indigo, 0.20)!,
      EinoMood.concerned || EinoMood.confused || EinoMood.pouting => Color.lerp(themeAccent, Theme.of(context).colorScheme.error, 0.35)!,
      EinoMood.calm => themeAccent,
    };

    return EinoOrb(
      size: size,
      accent: moodAccent,
      sleepAfter: const Duration(seconds: 30),
    );
  }
}

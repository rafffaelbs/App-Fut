import 'package:flutter/material.dart';

import '../../utils/cosmetic_resolver.dart';

/// Ícone cosmético (coroa, gema, troféu, chama, medalhas).
class CosmeticIcon extends StatelessWidget {
  final CosmeticIconSpec spec;
  final double size;

  const CosmeticIcon({super.key, required this.spec, this.size = 14});

  static IconData iconFor(CosmeticIconKind kind) {
    switch (kind) {
      case CosmeticIconKind.crown:
        return Icons.workspace_premium_rounded;
      case CosmeticIconKind.gem:
        return Icons.diamond_rounded;
      case CosmeticIconKind.trophy:
        return Icons.emoji_events_rounded;
      case CosmeticIconKind.flame:
        return Icons.local_fire_department_rounded;
      case CosmeticIconKind.medalSilver:
      case CosmeticIconKind.medalBronze:
        return Icons.military_tech_rounded;
    }
  }

  @override
  Widget build(BuildContext context) =>
      Icon(iconFor(spec.kind), color: spec.color, size: size);
}

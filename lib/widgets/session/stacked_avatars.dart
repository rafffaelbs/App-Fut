import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../shared/ranking_player_bits.dart';

/// Avatares sobrepostos (30%) dos confirmados: no máximo [maxVisible] e um
/// contador "+N" para o resto.
class StackedAvatars extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final int maxVisible;
  final double size;

  const StackedAvatars({
    super.key,
    required this.players,
    this.maxVisible = 5,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();
    final visible = players.take(maxVisible).toList();
    final extra = players.length - visible.length;
    final step = size * 0.7;
    final slots = visible.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      height: size,
      width: step * (slots - 1) + size,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * step,
              child: _Ring(
                size: size,
                child: RankAvatar(player: visible[i], size: size - 4),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * step,
              child: _Ring(
                size: size,
                child: Container(
                  width: size - 4,
                  height: size - 4,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '+$extra',
                    style: AppTheme.number(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Anel na cor do card para o recorte entre avatares sobrepostos.
class _Ring extends StatelessWidget {
  final double size;
  final Widget child;

  const _Ring({required this.size, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.headerBlue,
          shape: BoxShape.circle,
        ),
        child: child,
      );
}

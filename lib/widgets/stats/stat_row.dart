import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../shared/ranking_player_bits.dart';

/// Uma linha de ranking da tela de Estatísticas (jogador ou dupla).
/// [player]/[player2] seguem o formato de `GroupBootstrap.playerSnapshotMap`.
class StatRow {
  final Map<String, dynamic> player;
  final Map<String, dynamic>? player2;
  final String primary;
  final String? secondary;
  final Color primaryColor;

  /// Valor usado para o empate de posições (1, 1, 3).
  final num tieValue;

  const StatRow({
    required this.player,
    required this.primary,
    required this.tieValue,
    this.player2,
    this.secondary,
    this.primaryColor = AppColors.textWhite,
  });

  String get searchName =>
      '${player['name'] ?? ''} ${player2?['name'] ?? ''}'.toLowerCase();
}

/// Linha de ranking: posição · [avatar] · nome(s) com cosméticos · valores.
class StatRowTile extends StatelessWidget {
  final StatRow row;
  final int position;
  final double height;
  final bool showAvatar;
  final VoidCallback? onTap;

  const StatRowTile({
    super.key,
    required this.row,
    required this.position,
    this.height = 40,
    this.showAvatar = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const nameStyle = TextStyle(fontSize: 13);
    final names = row.player2 == null
        ? RankName(player: row.player, style: nameStyle)
        : Row(
            children: [
              Flexible(child: RankName(player: row.player, style: nameStyle, showStars: false)),
              const Text(' + ',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              Flexible(child: RankName(player: row.player2!, style: nameStyle, showStars: false)),
            ],
          );
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$position',
                style: AppTheme.number(
                  fontSize: 14,
                  color: position <= 3 ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
            if (showAvatar) ...[
              RankAvatar(player: row.player, size: 32),
              const SizedBox(width: 10),
            ],
            Expanded(child: names),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(row.primary,
                    style: AppTheme.number(fontSize: 16, color: row.primaryColor)),
                if (row.secondary != null)
                  Text(row.secondary!,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

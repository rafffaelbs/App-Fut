import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/overall_calculator.dart';
import '../../utils/bench_time_calculator.dart';
import '../player/fifa_card.dart';
import '../shared/player_avatar_frame.dart';
import '../shared/player_name_text.dart';

/// Card horizontal do "banco de reservas" (aba Próximos): posição na fila em
/// destaque, carta em densidade M, nome, tempo no banco e alça de arraste.
/// Quem é o próximo (#1) ganha moldura `accent`.
class WaitingPlayerCard extends StatelessWidget {
  final Map<String, dynamic> player;

  /// Posição na fila, a partir de 1.
  final int position;

  /// Índice na lista reordenável (alça de arraste).
  final int dragIndex;

  /// Estatísticas de tempo e jogos no banco derivadas do histórico.
  final WaitingBenchStats? benchStats;

  /// Legado: data desde quando está esperando (usado se [benchStats] for nulo).
  final DateTime? waitingSince;

  /// Cor do grupo quando já forma um time completo; null = sobra.
  final Color? batchColor;
  final bool isFirstInBatch;
  final bool isLastInBatch;
  final PlayerFrameInfo? frame;
  final VoidCallback onTap;

  const WaitingPlayerCard({
    super.key,
    required this.player,
    required this.position,
    required this.dragIndex,
    this.benchStats,
    this.waitingSince,
    required this.frame,
    required this.onTap,
    this.batchColor,
    this.isFirstInBatch = true,
    this.isLastInBatch = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNext = position == 1;
    final Color borderColor = isNext
        ? AppColors.accentBlue
        : (batchColor?.withValues(alpha: 0.6) ?? AppColors.borderSubtle);
    final community = player['community'] is CommunityAttributes
        ? player['community'] as CommunityAttributes
        : CommunityAttributes.fromMap(player);

    return Container(
      margin: EdgeInsets.only(bottom: isLastInBatch ? 12 : 2),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isFirstInBatch ? 12 : 4),
          bottom: Radius.circular(isLastInBatch ? 12 : 4),
        ),
        border: Border.all(color: borderColor, width: isNext ? 2 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '#$position',
                    style: AppTheme.number(
                      fontSize: isNext ? 22 : 18,
                      color: isNext ? AppColors.accentBlueLight : AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  height: 84,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: FifaCard(
                      name: player['name']?.toString() ?? '',
                      iconPath: player['icon']?.toString(),
                      overall: playerOverallOf(player).round(),
                      attributes: community,
                      frame: frame,
                      density: CardDensity.medium,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlayerNameText(
                        name: player['name'].toString(),
                        nameEffect: player['name_effect']?.toString(),
                        style: TextStyle(
                          color: isNext ? AppColors.textWhite : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _WaitingClock(
                        stats: benchStats ??
                            WaitingBenchStats(
                              hasPlayed: true,
                              waitingSince: waitingSince,
                              completedMatchesSinceLastPlayed: 0,
                            ),
                      ),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: GestureDetector(
                    onLongPressStart: (_) => HapticFeedback.selectionClick(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.drag_handle, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Exibe tempo e jogos no banco, atualizado periodicamente sem reconstruir a lista.
class _WaitingClock extends StatefulWidget {
  final WaitingBenchStats stats;
  const _WaitingClock({required this.stats});

  @override
  State<_WaitingClock> createState() => _WaitingClockState();
}

class _WaitingClockState extends State<_WaitingClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      BenchTimeCalculator.formatDisplay(widget.stats, now: DateTime.now()),
      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    );
  }
}

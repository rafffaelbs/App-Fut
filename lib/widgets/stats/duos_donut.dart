import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/stats_board_utils.dart';
import 'stat_board_card.dart';

/// Uma dupla e seus gols em parceria (autor + assistente, par não ordenado).
class DuoSlice {
  final String name1;
  final String name2;
  final int goals;
  const DuoSlice(this.name1, this.name2, this.goals);

  String get label => '$name1 + $name2';
}

/// Quadro "Duplas Dinâmicas": rosca das 5 primeiras duplas (= 100%).
class DuosDonutCard extends StatelessWidget {
  /// Todas as duplas, ordenadas por gols (a rosca usa só as 5 primeiras).
  final List<DuoSlice> duos;
  final VoidCallback onMore;
  final bool fillHeight;

  const DuosDonutCard({
    super.key,
    required this.duos,
    required this.onMore,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = duos.take(5).toList();
    final total = top.fold<int>(0, (a, d) => a + d.goals);
    final percents = largestRemainderPercents(top.map((d) => d.goals).toList());
    return StatBoardShell(
      title: 'Duplas Dinâmicas',
      subtitle: 'Gols em parceria (autor + assistente)',
      onMore: onMore,
      fillHeight: fillHeight,
      child: top.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Nenhuma parceria registrada.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          : Column(
              children: [
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(PieChartData(
                        centerSpaceRadius: 52,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(enabled: false),
                        sections: [
                          for (var i = 0; i < top.length; i++)
                            PieChartSectionData(
                              value: top[i].goals.toDouble(),
                              color: AppColors.chartPalette[i],
                              radius: 26,
                              showTitle: percents[i] >= 8,
                              title: '${percents[i]}%',
                              titleStyle: AppTheme.number(
                                fontSize: 12,
                                color: AppColors.deepBlue,
                              ),
                            ),
                        ],
                      )),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: AppTheme.number(fontSize: 26)),
                          const Text('gols',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < top.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.chartPalette[i],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${top[i].label} — ${top[i].goals} ${top[i].goals == 1 ? 'gol' : 'gols'} · ${percents[i]}%',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('% entre as 5 duplas',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                ),
              ],
            ),
    );
  }
}

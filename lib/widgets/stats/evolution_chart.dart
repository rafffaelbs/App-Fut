import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/match_model.dart';
import '../../utils/stats_board_utils.dart';
import 'player_picker_sheet.dart';

const _months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
const _plotHeight = 200.0;

String _fmt(num v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toStringAsFixed(1).replaceAll('.', ',');

/// Card "Evolução de Desempenho": um jogador por vez, 6 meses fixos, barras
/// G+A / Gols / Assistências, médias gerais tracejadas e comparação opcional.
class EvolutionChartCard extends StatefulWidget {
  /// Mapas no formato de `GroupBootstrap.playerSnapshotMap`.
  final List<Map<String, dynamic>> players;
  final List<MatchModel> matches;
  final DateTime now;

  const EvolutionChartCard({
    super.key,
    required this.players,
    required this.matches,
    required this.now,
  });

  @override
  State<EvolutionChartCard> createState() => _EvolutionChartCardState();
}

class _EvolutionChartCardState extends State<EvolutionChartCard> {
  String? _firstId;
  String? _secondId;

  late List<MonthAverage> _averages;
  List<MonthBucket> _first = const [];
  List<MonthBucket> _second = const [];
  bool _hasGames = false;

  @override
  void initState() {
    super.initState();
    _firstId = windowGaLeader(widget.matches, now: widget.now) ??
        (widget.players.isNotEmpty ? widget.players.first['id'] as String : null);
    _recompute();
  }

  @override
  void didUpdateWidget(covariant EvolutionChartCard old) {
    super.didUpdateWidget(old);
    if (old.matches != widget.matches || old.now != widget.now) _recompute();
  }

  void _recompute() {
    final months = lastMonths(widget.now);
    _hasGames = widget.matches.any(
        (m) => months.any((d) => d.year == m.timestamp.year && d.month == m.timestamp.month));
    _averages = monthlyGroupAverages(widget.matches, now: widget.now);
    _first = _firstId == null
        ? const []
        : monthlyEvolution(widget.matches, _firstId!, now: widget.now);
    _second = _secondId == null
        ? const []
        : monthlyEvolution(widget.matches, _secondId!, now: widget.now);
  }

  Map<String, dynamic>? _player(String? id) {
    for (final p in widget.players) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  Future<void> _pick({required bool second}) async {
    final id = await showPlayerPickerSheet(
      context,
      players: widget.players,
      excludeId: second ? _firstId : _secondId,
      title: second ? 'Comparar com' : 'Selecione o jogador',
    );
    if (id == null || !mounted) return;
    setState(() {
      if (second) {
        _secondId = id;
      } else {
        _firstId = id;
      }
      _recompute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p1 = _player(_firstId);
    final p2 = _player(_secondId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evolução de Desempenho',
            style: TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          const Text(
            'Últimos 6 meses',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PlayerChip(
                label: p1 == null ? 'Selecione o jogador' : (p1['name'] ?? '').toString(),
                icon: Icons.person_outline,
                onTap: () => _pick(second: false),
              ),
              _PlayerChip(
                label: p2 == null ? 'Comparar com' : (p2['name'] ?? '').toString(),
                icon: Icons.compare_arrows,
                dashed: true,
                onTap: () => _pick(second: true),
                onClear: p2 == null
                    ? null
                    : () => setState(() {
                          _secondId = null;
                          _recompute();
                        }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Legend(
            firstName: p1 == null ? null : (p1['name'] ?? '').toString(),
            secondName: p2 == null ? null : (p2['name'] ?? '').toString(),
          ),
          const SizedBox(height: 12),
          if (!_hasGames || p1 == null)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('Sem jogos nos últimos 6 meses',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            )
          else
            _Chart(first: _first, second: p2 == null ? null : _second, averages: _averages),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dashed;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _PlayerChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.dashed = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, maxWidth: 220),
          child: Padding(
            padding: EdgeInsets.only(left: 12, right: onClear == null ? 12 : 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                if (onClear != null)
                  IconButton(
                    tooltip: 'Remover comparação',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                    onPressed: onClear,
                  )
                else
                  const Icon(Icons.expand_more, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String? firstName;
  final String? secondName;
  const _Legend({required this.firstName, required this.secondName});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textMuted, fontSize: 12);
    Widget dot(Color c) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    Widget item(Widget mark, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [mark, const SizedBox(width: 6), Text(text, style: style)],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(dot(AppColors.chartGoalsAssists), 'G + A'),
        item(dot(AppColors.chartGoals), 'Gols'),
        item(dot(AppColors.chartAssists), 'Assistências'),
        item(
          CustomPaint(
            size: const Size(18, 2),
            painter: _DashPainter(AppColors.textMuted),
          ),
          'Média geral',
        ),
        if (secondName != null) ...[
          item(dot(AppColors.textPrimary), '${firstName ?? ''} (cheia)'),
          item(
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary, width: 1.5),
              ),
            ),
            '$secondName (pontilhada)',
          ),
        ],
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(min(x + 3, size.width), size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

class _Chart extends StatelessWidget {
  final List<MonthBucket> first;
  final List<MonthBucket>? second;
  final List<MonthAverage> averages;

  const _Chart({required this.first, required this.second, required this.averages});

  @override
  Widget build(BuildContext context) {
    final avgGa = _mean(averages.map((a) => a.ga));
    final avgGoals = _mean(averages.map((a) => a.goals));
    final avgAssists = _mean(averages.map((a) => a.assists));

    var maxVal = [avgGa, avgGoals, avgAssists].reduce(max);
    for (final b in first) {
      maxVal = max(maxVal, b.ga.toDouble());
    }
    for (final b in second ?? const <MonthBucket>[]) {
      maxVal = max(maxVal, b.ga.toDouble());
    }
    final interval = max(1, (maxVal / 4).ceil()).toDouble();
    final maxY = interval * 4;
    final minBar = maxY * 2 / _plotHeight; // zero = traço de 2dp

    BarChartData data({required List<MonthBucket> buckets, required bool dark, required bool base}) {
      final colors = dark
          ? [AppColors.chartGoalsAssistsDark, AppColors.chartGoalsDark, AppColors.chartAssistsDark]
          : [AppColors.chartGoalsAssists, AppColors.chartGoals, AppColors.chartAssists];
      BarChartRodData rod(int v, Color c) => BarChartRodData(
            toY: v == 0 ? minBar : v.toDouble(),
            width: 10,
            color: dark ? c.withValues(alpha: 0.35) : c,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            borderSide: dark ? BorderSide(color: c, width: 1.5) : BorderSide.none,
            borderDashArray: dark ? const [3, 2] : null,
          );
      return BarChartData(
        minY: 0,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: 8,
        gridData: FlGridData(
          show: base,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (v, meta) => base
                  ? SideTitleWidget(
                      meta: meta,
                      child: Text(_fmt(v),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) => base
                  ? SideTitleWidget(
                      meta: meta,
                      child: Text(_months[buckets[v.toInt()].month.month - 1],
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        extraLinesData: base
            ? ExtraLinesData(horizontalLines: _avgLines(avgGa, avgGoals, avgAssists, maxY))
            : null,
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                rod(buckets[i].ga, colors[0]),
                rod(buckets[i].goals, colors[1]),
                rod(buckets[i].assists, colors[2]),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          enabled: base,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated,
            getTooltipItem: (group, gi, rod, ri) {
              if (ri != 0) return null;
              final m = first[group.x];
              final s = second?[group.x];
              String line(String who, MonthBucket b) =>
                  '$who  G+A ${b.ga} · Gols ${b.goals} · Ast ${b.assists}';
              return BarTooltipItem(
                '${_months[m.month.month - 1]}\n${line(second == null ? '' : 'Cheia:', m).trim()}'
                '${s == null ? '' : '\n${line('Pontilhada:', s)}'}',
                const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              );
            },
          ),
        ),
      );
    }

    return SizedBox(
      height: _plotHeight + 24,
      child: Stack(
        children: [
          Positioned.fill(child: BarChart(data(buckets: first, dark: false, base: true))),
          if (second != null)
            Positioned.fill(
              child: IgnorePointer(
                child: BarChart(data(buckets: second!, dark: true, base: false)),
              ),
            ),
        ],
      ),
    );
  }

  static double _mean(Iterable<double> v) {
    final l = v.toList();
    return l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
  }

  /// Linhas de média geral; rótulos sobem em degraus quando as linhas ficam
  /// a menos de ~14dp umas das outras.
  List<HorizontalLine> _avgLines(double ga, double goals, double assists, double maxY) {
    final series = [
      ('méd. G+A', ga, AppColors.chartGoalsAssists),
      ('méd. Gols', goals, AppColors.chartGoals),
      ('méd. Ast', assists, AppColors.chartAssists),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final out = <HorizontalLine>[];
    var lastLabelY = -100.0;
    for (final s in series) {
      final y = s.$2 / maxY * _plotHeight;
      final labelY = max(y, lastLabelY + 14);
      lastLabelY = labelY;
      out.add(HorizontalLine(
        y: s.$2,
        color: s.$3,
        strokeWidth: 1,
        dashArray: const [5, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: EdgeInsets.only(bottom: labelY - y),
          style: TextStyle(color: s.$3, fontSize: 10, fontWeight: FontWeight.w600),
          labelResolver: (_) => '${s.$1} ${_fmt(double.parse(s.$2.toStringAsFixed(1)))}',
        ),
      ));
    }
    return out;
  }
}

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/player_session_summary.dart';

const List<String> _months = [
  'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
  'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// Conteúdo da aba "Peladas" da carta do jogador: as [previewCount] últimas
/// peladas e um botão "Ver mais" que abre a lista completa. Somente leitura.
class PlayerSessionsList extends StatelessWidget {
  final List<PlayerSessionSummary> summaries;

  /// Nome da pelada por id. Sem nome (ou vazio), mostra "Pelada de dd/MM/aaaa".
  final Map<String, String> titles;
  final int previewCount;

  const PlayerSessionsList({
    super.key,
    required this.summaries,
    this.titles = const {},
    this.previewCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Sem peladas no período',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final preview = summaries.take(previewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in preview) ...[
          PlayerSessionTile(summary: s, title: titles[s.sessionId]),
          const SizedBox(height: 8),
        ],
        if (summaries.length > previewCount)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => _openAll(context),
              child: const Text(
                'Ver mais',
                style: TextStyle(
                  color: AppColors.accentBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.headerBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Peladas (${summaries.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: summaries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => PlayerSessionTile(
                  summary: summaries[i],
                  title: titles[summaries[i].sessionId],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de uma pelada: data, nome, gols/assistências/G+A e V/E/D.
class PlayerSessionTile extends StatelessWidget {
  final PlayerSessionSummary summary;
  final String? title;

  const PlayerSessionTile({super.key, required this.summary, this.title});

  @override
  Widget build(BuildContext context) {
    final d = summary.date;
    final String fullDate =
        d == null ? 'sem data' : '${_two(d.day)}/${_two(d.month)}/${d.year}';
    final String name = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : 'Pelada de $fullDate';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateBadge(date: d),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$fullDate · ${summary.matches} '
                      '${summary.matches == 1 ? 'jogo' : 'jogos'}',
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Gols', value: summary.goals),
              _Stat(label: 'Assist.', value: summary.assists),
              _Stat(
                label: 'G+A',
                value: summary.ga,
                color: AppColors.highlightGreen,
              ),
              const Spacer(),
              _Result(letter: 'V', value: summary.wins, color: AppColors.success),
              const SizedBox(width: 8),
              _Result(letter: 'E', value: summary.draws, color: Colors.amber),
              const SizedBox(width: 8),
              _Result(
                letter: 'D',
                value: summary.losses,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime? date;
  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            date == null ? '--' : _two(date!.day),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            date == null ? '' : _months[date!.month - 1],
            style: const TextStyle(color: AppColors.textDim, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textDim, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final String letter;
  final int value;
  final Color color;

  const _Result({
    required this.letter,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(value > 0 ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value$letter',
        style: TextStyle(
          color: value > 0 ? color : AppColors.textDim,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

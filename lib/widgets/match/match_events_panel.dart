import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class MatchEventsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const MatchEventsPanel({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, color: AppColors.accentBlue, size: 16),
              SizedBox(width: 8),
              Text(
                'Eventos da partida',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Nenhum evento ainda. Toque em um jogador para registrar gol ou cartão.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else
            ...events.asMap().entries.map((e) => _EventRow(event: e.value)),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = event['type']?.toString() ?? '';
    final isRed = event['team'] == 'Vermelho';
    final icon = _iconFor(type);
    final color = _colorFor(type);
    final assist = event['assist']?.toString();
    final subtitle = type == 'goal'
        ? (assist != null && assist.isNotEmpty ? 'Assistência: $assist' : 'Gol')
        : type == 'own_goal'
            ? 'Gol contra'
            : type == 'yellow_card'
                ? 'Cartão amarelo'
                : type == 'red_card'
                    ? 'Cartão vermelho'
                    : type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              event['time']?.toString() ?? '',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['player']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isRed ? Colors.redAccent : Colors.white)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isRed ? 'VER' : 'BRA',
              style: TextStyle(
                color: isRed ? Colors.redAccent : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'goal':
        return Icons.sports_soccer;
      case 'own_goal':
        return Icons.error_outline;
      case 'yellow_card':
      case 'red_card':
        return Icons.style;
      default:
        return Icons.circle;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'goal':
        return Colors.greenAccent;
      case 'own_goal':
        return Colors.redAccent;
      case 'yellow_card':
        return Colors.yellow;
      case 'red_card':
        return Colors.red;
      default:
        return Colors.white54;
    }
  }
}

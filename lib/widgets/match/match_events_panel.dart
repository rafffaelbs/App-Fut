import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

/// Timeline da partida em "peek": uma faixa de 56dp com o último evento
/// embaixo do campo; arrastar para cima (ou tocar) abre a lista completa.
/// Toque num evento chama [onEventTap] (destaca o jogador no campo).
///
/// Deve ficar num `Stack` com altura limitada (ocupa a parte de baixo).
class MatchEventsPanel extends StatelessWidget {
  static const double peekHeight = 56;

  final List<Map<String, dynamic>> events;
  final ValueChanged<Map<String, dynamic>>? onEventTap;

  const MatchEventsPanel({super.key, required this.events, this.onEventTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final minSize = (peekHeight / c.maxHeight).clamp(0.05, 0.9);
        return DraggableScrollableSheet(
          initialChildSize: minSize,
          minChildSize: minSize,
          maxChildSize: 0.7,
          snap: true,
          snapSizes: const [0.7],
          builder: (context, controller) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                SizedBox(
                  height: peekHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: AppColors.textDim,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      if (events.isEmpty)
                        const Text(
                          'Nenhum evento ainda',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        )
                      else
                        _EventRow(
                          event: events.last,
                          compact: true,
                          onTap: onEventTap,
                        ),
                    ],
                  ),
                ),
                if (events.length > 1 || events.isNotEmpty)
                  for (final e in events.reversed)
                    _EventRow(event: e, onTap: onEventTap),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool compact;
  final ValueChanged<Map<String, dynamic>>? onTap;
  const _EventRow({required this.event, this.compact = false, this.onTap});

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

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(event),
      child: Padding(
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
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontFamily: AppTheme.numberFont,
                  fontWeight: FontWeight.w600,
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
                      color: AppColors.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isRed ? AppColors.redTeam : AppColors.whiteTeam)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isRed ? 'VER' : 'BRA',
                style: TextStyle(
                  color: isRed ? AppColors.redTeam : AppColors.textWhite,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
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
        return AppColors.success;
      case 'own_goal':
        return AppColors.redTeam;
      case 'yellow_card':
        return AppColors.yellowWarning;
      case 'red_card':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }
}

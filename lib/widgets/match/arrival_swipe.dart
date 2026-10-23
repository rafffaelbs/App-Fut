import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Gestos da lista de Chegada: quem está ativo desliza para a esquerda
/// ("Faltou"); quem desistiu desliza para a direita ("Chegou", volta à lista).
/// Quem desistiu fica em *ghost mode* (40%, escala de cinza). O chamador
/// aplica a mudança e oferece o desfazer.
class ArrivalSwipe extends StatelessWidget {
  final String playerId;
  final bool absent;
  final VoidCallback onAbsent;
  final VoidCallback onArrived;
  final Widget child;

  const ArrivalSwipe({
    super.key,
    required this.playerId,
    required this.absent,
    required this.onAbsent,
    required this.onArrived,
    required this.child,
  });

  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final content = absent
        ? Opacity(
            opacity: 0.4,
            child: ColorFiltered(colorFilter: _grayscale, child: child),
          )
        : child;

    return Dismissible(
      // A chave inclui o estado: depois do swipe o item reaparece como outro.
      key: ValueKey('arrival_${playerId}_$absent'),
      direction:
          absent ? DismissDirection.startToEnd : DismissDirection.endToStart,
      background: const _SwipeBackground(
        color: AppColors.success,
        icon: Icons.check,
        label: 'Chegou',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const _SwipeBackground(
        color: AppColors.danger,
        icon: Icons.close,
        label: 'Faltou',
        alignment: Alignment.centerRight,
      ),
      onDismissed: (direction) =>
          direction == DismissDirection.startToEnd ? onArrived() : onAbsent(),
      child: content,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final bool left = alignment == Alignment.centerLeft;
    final children = <Widget>[
      Icon(icon, color: AppColors.textWhite),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w600,
              fontSize: 12)),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      // No início do arraste o fundo é mais estreito que o rótulo.
      child: ClipRect(
        child: OverflowBox(
          alignment: alignment,
          minWidth: 0,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: left ? children : children.reversed.toList(),
          ),
        ),
      ),
    );
  }
}

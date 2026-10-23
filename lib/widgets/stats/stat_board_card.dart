import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/stats_board_utils.dart';
import 'stat_row.dart';

/// Rodapé "Ver mais ›" (área de toque de 48dp).
class SeeMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const SeeMoreButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const SizedBox(
        height: 48,
        child: Center(
          child: Text(
            'Ver mais ›',
            style: TextStyle(
              color: AppColors.highlightBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Casca dos quadros da grade: surface1 + borda, raio 12, rodapé "Ver mais".
class StatBoardShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onMore;

  /// true quando a altura vem de fora (grade em 2 colunas): empurra o
  /// rodapé para a base. Em lista rolável a altura é livre, então false.
  final bool fillHeight;

  const StatBoardShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onMore,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
          if (fillHeight) const Spacer(),
          const Divider(color: AppColors.borderSubtle, height: 1),
          if (onMore != null) SeeMoreButton(onTap: onMore!),
        ],
      ),
    );
  }
}

/// Quadro com o top 5 de uma lista de [StatRow] (já ordenada).
class StatBoardCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<StatRow> rows;
  final String emptyText;
  final VoidCallback onMore;
  final bool fillHeight;
  final void Function(StatRow row)? onTapRow;

  const StatBoardCard({
    super.key,
    required this.title,
    required this.rows,
    required this.emptyText,
    required this.onMore,
    this.subtitle,
    this.fillHeight = false,
    this.onTapRow,
  });

  @override
  Widget build(BuildContext context) {
    final top = rows.take(5).toList();
    final positions = rankWithTies(top.map((r) => r.tieValue).toList());
    return StatBoardShell(
      title: title,
      subtitle: subtitle,
      onMore: onMore,
      fillHeight: fillHeight,
      child: top.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(emptyText,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          : Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  StatRowTile(
                    row: top[i],
                    position: positions[i],
                    onTap: onTapRow == null ? null : () => onTapRow!(top[i]),
                  ),
              ],
            ),
    );
  }
}

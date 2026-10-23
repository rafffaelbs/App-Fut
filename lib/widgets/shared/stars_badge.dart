import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Estrelas do Craque do Mês: 1–3 ★ individuais, 4–6 (ou [compact]) `★N`.
class StarsBadge extends StatelessWidget {
  final int stars;
  final bool compact;
  final double size;

  const StarsBadge({
    super.key,
    required this.stars,
    this.compact = false,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (stars <= 0) return const SizedBox.shrink();

    Widget star() =>
        Icon(Icons.star_rounded, color: AppColors.cosmeticStar, size: size);

    if (!compact && stars <= 3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < stars; i++) star()],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        star(),
        Text(
          '$stars',
          style: TextStyle(
            color: AppColors.cosmeticStar,
            fontSize: size < 10 ? 10 : size,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ],
    );
  }
}

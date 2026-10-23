import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/cosmetic_resolver.dart';
import '../../utils/overall_calculator.dart';
import '../player/fifa_card.dart';
import 'cosmetic_frame.dart';
import 'cosmetic_name.dart';
import 'player_avatar_frame.dart';
import 'stars_badge.dart';

/// Peças compartilhadas por ranking, lista completa e Elenco, para que o
/// mesmo jogador tenha a mesma cara (cor + ícone + estrelas) em todo lugar.

ResolvedCosmetic cosmeticOfMap(Map<String, dynamic> p) =>
    resolveCosmetic(PlayerCosmetics.fromMap(p));

/// Avatar redondo com moldura cosmética. Sem estrelas/ícone sobre o avatar:
/// quem usa decide onde mostrá-los ([RankName] ou [StarsBadge] abaixo).
class RankAvatar extends StatelessWidget {
  final Map<String, dynamic> player;
  final double size;
  final bool glow;

  const RankAvatar({
    super.key,
    required this.player,
    this.size = 40,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = player['icon'] as String?;
    final name = (player['name'] ?? '').toString();
    final hasIcon = icon != null && icon.isNotEmpty;
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.headerBlue,
      backgroundImage: hasIcon ? AssetImage(icon) : null,
      child: hasIcon
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
              ),
            ),
    );
    return CosmeticFrame(
      cosmetic: cosmeticOfMap(player),
      thickness: size >= 56 ? 2.5 : 2,
      gap: 1.5,
      glow: glow,
      child: avatar,
    );
  }
}

/// Nome cosmético + ícone no fim + estrelas compactas (linha de lista).
class RankName extends StatelessWidget {
  final Map<String, dynamic> player;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool showStars;

  const RankName({
    super.key,
    required this.player,
    this.style,
    this.textAlign,
    this.showStars = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = cosmeticOfMap(player);
    final name = CosmeticName(
      name: (player['name'] ?? '').toString(),
      cosmetic: c,
      showIcon: true,
      iconSize: 14,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: (style ?? const TextStyle(fontSize: 14)).copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!showStars || c.stars == 0) return name;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: name),
        const SizedBox(width: 4),
        StarsBadge(stars: c.stars, compact: true, size: 12),
      ],
    );
  }
}

/// Nota em pílula sólida (sem glow, texto branco).
class RatingPill extends StatelessWidget {
  final double rating;
  final double fontSize;

  const RatingPill({super.key, required this.rating, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ratingPill(rating),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rating.toStringAsFixed(1),
        style: AppTheme.number(
          fontSize: fontSize,
          color: AppColors.textWhite,
        ),
      ),
    );
  }
}

/// "V 3  E 1  D 0", com letras (verde / cinza / vermelho).
/// Gols e assistências separados: `⚽ 2 · 👟 1` (mín. 10sp).
class GoalsAssistsText extends StatelessWidget {
  final int goals;
  final int assists;
  final double fontSize;

  const GoalsAssistsText({
    super.key,
    required this.goals,
    required this.assists,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '⚽ $goals · 👟 $assists',
      style: TextStyle(
        fontSize: fontSize < 10 ? 10 : fontSize,
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class WdlText extends StatelessWidget {
  final int wins;
  final int draws;
  final int losses;
  final double fontSize;

  const WdlText({
    super.key,
    required this.wins,
    required this.draws,
    required this.losses,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    TextSpan part(String letter, int n, Color color) => TextSpan(
          text: '$letter $n',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        );
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, color: AppColors.textMuted),
        children: [
          part('V', wins, AppColors.success),
          const TextSpan(text: '  '),
          part('E', draws, AppColors.textMuted),
          const TextSpan(text: '  '),
          part('D', losses, AppColors.danger),
        ],
      ),
    );
  }
}

/// Peek da carta completa (mesmo componente do campo e do Elenco).
void showPlayerCardPeek(BuildContext context, Map<String, dynamic> player) {
  final rating = ((player['nota'] ?? player['rating'] ?? 6.0) as num).toDouble();
  final community = player['community'] as CommunityAttributes?;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: SizedBox(
          width: FifaCard.designWidth * 1.4,
          height: FifaCard.designHeight * 1.4,
          child: FifaCard(
            name: (player['name'] ?? '').toString(),
            iconPath: player['icon'] as String?,
            overall: calculateOverall(appRating10: rating, community: community),
            attributes: community,
            frame: resolvePlayerFrame(player),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

/// Cores padronizadas dos efeitos de nome. Usadas aqui e em qualquer tela
/// que precise pintar um ring/badge com a mesma cor do efeito (ex.: pódio
/// do ranking).
class PlayerNameEffectColors {
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  /// Retorna a cor do efeito, ou null se não houver efeito (nome padrão).
  static Color? forEffect(String? effect) {
    switch (effect) {
      case 'gold':
        return gold;
      case 'silver':
        return silver;
      case 'bronze':
        return bronze;
      default:
        return null;
    }
  }
}

/// Widget único e reutilizável para renderizar o nome de um jogador,
/// aplicando o efeito visual (`nameEffect`: 'gold' | 'silver' | 'bronze' |
/// null) de forma consistente em qualquer tela do app.
///
/// Troque todo `Text(player.name)` / `Text(player['name'])` por
/// `PlayerNameText(name: ..., nameEffect: ...)` para que o efeito apareça
/// automaticamente em todo lugar.
class PlayerNameText extends StatelessWidget {
  final String name;
  final String? nameEffect;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PlayerNameText({
    super.key,
    required this.name,
    this.nameEffect,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final effectColor = PlayerNameEffectColors.forEffect(nameEffect);

    final effectiveStyle = effectColor == null
        ? baseStyle
        : baseStyle.copyWith(
            color: effectColor,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: effectColor.withOpacity(0.45),
                blurRadius: 6,
              ),
            ],
          );

    return Text(
      name,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Decoração de anel/destaque para o avatar do "craque do mês", usada
/// apenas no pódio do ranking (top posições), nunca em listas compactas.
/// Envolva o avatar existente com este widget.
class MonthlyHighlightAvatarRing extends StatelessWidget {
  final Widget avatar;
  final bool highlighted;
  final double ringWidth;

  const MonthlyHighlightAvatarRing({
    super.key,
    required this.avatar,
    required this.highlighted,
    this.ringWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (!highlighted) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: PlayerNameEffectColors.gold,
              width: ringWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: PlayerNameEffectColors.gold.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: EdgeInsets.all(ringWidth),
          child: avatar,
        ),
        Positioned(
          bottom: -6,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: PlayerNameEffectColors.gold,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// Cores padronizadas dos efeitos de nome. Usadas aqui e em qualquer tela
/// que precise pintar um ring/badge com a mesma cor do efeito (ex.: pódio
/// do ranking).
class PlayerNameEffectColors {
  static const Color gold = Color(0xFFF59E0B);
  static const Color silver = Color(0xFFCBD5E1);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color fire = Color(0xFFEA580C);
  static const Color diamond = Color(0xFF0EA5E9);

  /// Retorna a cor do efeito, ou null se não houver efeito (nome padrão).
  static Color? forEffect(String? effect) {
    switch (effect) {
      case 'gold':
        return gold;
      case 'silver':
        return silver;
      case 'bronze':
        return bronze;
      case 'fire':
        return fire;
      case 'diamond':
        return diamond;
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
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(
                color: Colors.black87,
                offset: Offset(0, 1),
                blurRadius: 2,
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
    this.ringWidth = 2.5,
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
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(ringWidth),
          child: avatar,
        ),
        Positioned(
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E293B),
              border: Border.all(color: PlayerNameEffectColors.gold, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: PlayerNameEffectColors.gold,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }
}

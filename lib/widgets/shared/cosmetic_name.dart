import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/cosmetic_resolver.dart';
import 'cosmetic_icon.dart';

/// Nome do jogador estilizado pelo [ResolvedCosmetic].
///
/// [solid] usa a cor média do gradiente (campo M/S, timeline). [plaque]
/// põe o nome sobre a plaqueta escura (cartas). [showIcon] acrescenta o
/// ícone do efeito ao fim do nome (listas).
class CosmeticName extends StatelessWidget {
  final String name;
  final ResolvedCosmetic cosmetic;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool solid;
  final bool plaque;
  final bool compactPlaque;
  final bool showIcon;
  final double iconSize;

  const CosmeticName({
    super.key,
    required this.name,
    required this.cosmetic,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.solid = false,
    this.plaque = false,
    this.compactPlaque = false,
    this.showIcon = false,
    this.iconSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final styled = cosmetic.source.nameEffect.dbValue != null;
    final nameStyle = cosmetic.nameStyle;

    Widget text;
    if (!styled) {
      text = Text(name,
          style: base,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow);
    } else if (solid || !nameStyle.isGradient) {
      text = Text(name,
          style: base.copyWith(
              color: nameStyle.solid, fontWeight: FontWeight.w700),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow);
    } else {
      text = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(colors: nameStyle.colors)
            .createShader(rect),
        child: Text(name,
            style: base.copyWith(
                color: AppColors.textWhite, fontWeight: FontWeight.w700),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow),
      );
    }

    final icon = cosmetic.nameIcon ?? cosmetic.primaryIcon;
    if (showIcon && icon != null) {
      text = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: text),
          const SizedBox(width: 4),
          CosmeticIcon(spec: icon, size: iconSize),
        ],
      );
    }

    if (plaque && styled) {
      text = Container(
        padding: compactPlaque
            ? const EdgeInsets.symmetric(horizontal: 2, vertical: 1)
            : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.cosmeticNamePlate,
          borderRadius: BorderRadius.circular(4),
        ),
        child: text,
      );
    }
    return text;
  }
}

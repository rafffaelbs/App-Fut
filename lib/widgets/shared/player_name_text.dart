import 'package:flutter/material.dart';

import '../../models/cosmetic_effect.dart';
import '../../utils/cosmetic_resolver.dart';
import 'cosmetic_name.dart';

/// Nome de jogador com o efeito cosmético aplicado (via [resolveCosmetic]).
///
/// Passe [cosmetic] (já resolvido) quando houver; senão [nameEffect]
/// ('diamond' | 'gold' | 'fire' | 'silver' | 'bronze' | null) é resolvido aqui.
/// Para ícone, plaqueta ou cor sólida, use [CosmeticName] diretamente.
class PlayerNameText extends StatelessWidget {
  final String name;
  final String? nameEffect;
  final ResolvedCosmetic? cosmetic;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PlayerNameText({
    super.key,
    required this.name,
    this.nameEffect,
    this.cosmetic,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return CosmeticName(
      name: name,
      cosmetic: cosmetic ??
          resolveCosmetic(
              PlayerCosmetics(nameEffect: CosmeticEffect.fromDb(nameEffect))),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

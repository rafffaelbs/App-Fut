import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/cosmetic_effects.dart';
import '../models/cosmetic_effect.dart';
import '../models/player_model.dart';

/// Dados brutos de cosméticos de um jogador (o admin decide quem ganha o quê).
class PlayerCosmetics {
  final bool goldenBall;
  final CosmeticEffect nameEffect;

  /// 0 = sem Craque do Mês, 1..6 = estrelas.
  final int monthlyStars;

  const PlayerCosmetics({
    this.goldenBall = false,
    this.nameEffect = CosmeticEffect.none,
    this.monthlyStars = 0,
  });

  static const none = PlayerCosmetics();

  factory PlayerCosmetics.fromPlayer(PlayerModel p) => PlayerCosmetics(
        goldenBall: p.goldenBall,
        nameEffect: p.cosmeticEffect,
        monthlyStars: p.monthlyStarCount,
      );

  /// Aceita os mapas usados pelas telas (inclui o fallback legado do model).
  factory PlayerCosmetics.fromMap(Map<String, dynamic> map) =>
      PlayerCosmetics.fromPlayer(PlayerModel.fromMap(map));
}

/// Nome: cor sólida ou gradiente de 2 cores.
class NameStyle {
  final List<Color> colors;
  const NameStyle(this.colors);

  static const plain = NameStyle([AppColors.textPrimary]);

  bool get isGradient => colors.length > 1;

  /// Cor sólida (média do gradiente), usada em campo M/S e na timeline.
  Color get solid => Color.lerp(colors.first, colors.last, 0.5)!;
}

enum FrameSource { none, goldenBall, nameEffect, monthly }

/// Moldura principal; [innerColor] vira a linha interna safira (moldura dupla).
class FrameStyle {
  final List<Color> colors;
  final Color? innerColor;
  const FrameStyle(this.colors, {this.innerColor});

  Color get primary => colors.first;
  bool get isDouble => innerColor != null;
}

class ResolvedCosmetic {
  final PlayerCosmetics source;
  final NameStyle nameStyle;
  final FrameStyle? frame;
  final FrameSource frameSource;
  final int stars;
  final bool allowsGlow;

  const ResolvedCosmetic({
    required this.source,
    required this.nameStyle,
    required this.frame,
    required this.frameSource,
    required this.stars,
    required this.allowsGlow,
  });

  /// Cor representativa do efeito (para amostras e destaques), ou null.
  Color? get accent => frame?.primary;
}

const _goldenBallFrame = [
  AppColors.cosmeticGoldenBallFrom,
  AppColors.cosmeticGoldenBallMid,
  AppColors.cosmeticGoldenBallTo,
];

const _sapphireFrame = [AppColors.cosmeticSapphire, AppColors.cosmeticSapphireHighlight];

/// Fonte única de verdade dos cosméticos. Nenhuma tela decide cor ou ícone
/// de efeito por conta própria.
///
/// - Moldura: Bola de Ouro > Efeito de nome > Craque do Mês. O Craque do Mês
///   vira linha interna (moldura dupla) quando há outra moldura.
ResolvedCosmetic resolveCosmetic(PlayerCosmetics c) {
  final effect = cosmeticEffectDef(c.nameEffect);
  final stars = c.monthlyStars.clamp(0, 6);
  final hasMonthly = stars > 0;

  FrameStyle? frame;
  FrameSource source = FrameSource.none;
  if (c.goldenBall) {
    source = FrameSource.goldenBall;
    frame = FrameStyle(_goldenBallFrame,
        innerColor: hasMonthly ? AppColors.cosmeticSapphire : null);
  } else if (effect != null) {
    source = FrameSource.nameEffect;
    frame = FrameStyle([effect.frameColor],
        innerColor: hasMonthly ? AppColors.cosmeticSapphire : null);
  } else if (hasMonthly) {
    source = FrameSource.monthly;
    frame = const FrameStyle(_sapphireFrame);
  }

  return ResolvedCosmetic(
    source: c,
    nameStyle: effect == null ? NameStyle.plain : NameStyle(effect.nameColors),
    frame: frame,
    frameSource: source,
    stars: stars,
    allowsGlow: c.goldenBall || (effect?.glow ?? false),
  );
}

/// Cor representativa de um efeito de nome (amostras de cor e destaques).
Color? cosmeticEffectColor(CosmeticEffect effect) =>
    resolveCosmetic(PlayerCosmetics(nameEffect: effect)).accent;

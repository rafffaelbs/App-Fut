import 'package:flutter/material.dart';

import '../models/cosmetic_effect.dart';
import 'app_colors.dart';

/// Definição de um efeito de nome (`players.name_effect`). Lista única:
/// um novo prêmio entra aqui (e no enum [CosmeticEffect]) sem mexer em telas.
class CosmeticEffectDef {
  final CosmeticEffect effect;

  /// Rótulo curto (sem emoji) e emoji usado só como legenda na tela de edição.
  final String label;
  final String legendEmoji;
  final String description;

  /// Cor do nome: 1 cor = sólida, 2+ = gradiente.
  final List<Color> nameColors;
  final Color frameColor;
  final bool glow;

  const CosmeticEffectDef({
    required this.effect,
    required this.label,
    required this.legendEmoji,
    required this.description,
    required this.nameColors,
    required this.frameColor,
    required this.glow,
  });

  /// "Dourado 🏆", como aparece na tela de edição.
  String get legendLabel => '$label $legendEmoji';
}

/// Ordem de exibição na tela de edição.
const kCosmeticEffects = <CosmeticEffectDef>[
  CosmeticEffectDef(
    effect: CosmeticEffect.diamond,
    label: 'Diamante',
    legendEmoji: '💎',
    description: 'Ciano cristalino (Lendário / MVP)',
    nameColors: [AppColors.cosmeticDiamondFrom, AppColors.cosmeticDiamond],
    frameColor: AppColors.cosmeticDiamond,
    glow: true,
  ),
  CosmeticEffectDef(
    effect: CosmeticEffect.gold,
    label: 'Dourado',
    legendEmoji: '🏆',
    description: 'Ouro reluzente (Bola de Ouro, eleito em votação no fim da temporada)',
    nameColors: [AppColors.cosmeticGoldFrom, AppColors.cosmeticGold],
    frameColor: AppColors.cosmeticGold,
    glow: true,
  ),
  CosmeticEffectDef(
    effect: CosmeticEffect.fire,
    label: 'Fogo',
    legendEmoji: '🔥',
    description: 'Chamas vivas (Artilheiro da temporada)',
    nameColors: [AppColors.cosmeticFireFrom, AppColors.cosmeticFire],
    frameColor: AppColors.cosmeticFire,
    glow: true,
  ),
  CosmeticEffectDef(
    effect: CosmeticEffect.silver,
    label: 'Prata',
    legendEmoji: '🥈',
    description: 'Cromo prateado (Vice-artilheiro / Garçom)',
    nameColors: [AppColors.cosmeticSilverFrom, AppColors.cosmeticSilverTo],
    frameColor: AppColors.cosmeticSilverFrame,
    glow: false,
  ),
  CosmeticEffectDef(
    effect: CosmeticEffect.bronze,
    label: 'Bronze',
    legendEmoji: '🥉',
    description: 'Cobre nobre (3º colocado / Revelação)',
    nameColors: [AppColors.cosmeticBronzeFrom, AppColors.cosmeticBronze],
    frameColor: AppColors.cosmeticBronze,
    glow: false,
  ),
];

/// Sem efeito (`name_effect` NULL).
const kNoCosmeticEffectLabel = 'Padrão (sem efeito)';
const kNoCosmeticEffectDescription = 'Sem prêmio';

CosmeticEffectDef? cosmeticEffectDef(CosmeticEffect effect) {
  for (final d in kCosmeticEffects) {
    if (d.effect == effect) return d;
  }
  return null;
}

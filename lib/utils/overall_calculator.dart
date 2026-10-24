import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// ============================================================
/// overall_calculator.dart
/// ============================================================
/// Overall estilo FIFA (0-99), combinando:
///   - Nota do App (0-10, calculada pelas estatísticas de jogo) -> x10
///   - Nota da Comunidade (0-100, média dos 6 atributos votados)
///
///   Overall = NotaApp100 * kOverallAppWeight + NotaComunidade * kOverallCommunityWeight
///   (hoje 0.30 / 0.70 -- ver constantes abaixo)
///
/// Sem Nota da Comunidade, usa 50 no lugar (neutro).
/// ============================================================

const double kOverallAppWeight = 0.3;
const double kOverallCommunityWeight = 0.7;

/// Valor neutro usado quando o jogador ainda não tem Nota da Comunidade.
const double kCommunityNeutral = 50.0;

/// Teto do Overall exibido (estilo FIFA: ninguém chega a 100).
const int kOverallMax = 99;

/// Os 6 atributos da comunidade, na ordem de exibição do card FIFA
/// (coluna esquerda: PAC/SHO/PAS, coluna direita: DRI/DEF/PHY).
const List<String> kAttributeKeys = ['pac', 'sho', 'pas', 'dri', 'def', 'phy'];

const Map<String, String> kAttributeLabels = {
  'pac': 'PAC',
  'sho': 'SHO',
  'pas': 'PAS',
  'dri': 'DRI',
  'def': 'DEF',
  'phy': 'PHY',
};

const Map<String, String> kAttributeDescriptions = {
  'pac': 'Velocidade',
  'sho': 'Finalização',
  'pas': 'Passe',
  'dri': 'Drible / Controle',
  'def': 'Marcação',
  'phy': 'Fôlego / Físico',
};

/// Atributos votados pela comunidade (0-100). Qualquer campo pode ser nulo.
class CommunityAttributes {
  final int? pac;
  final int? sho;
  final int? pas;
  final int? dri;
  final int? def;
  final int? phy;

  /// Quando preenchido, substitui a média dos 6 atributos.
  final double? ratingOverride;

  const CommunityAttributes({
    this.pac,
    this.sho,
    this.pas,
    this.dri,
    this.def,
    this.phy,
    this.ratingOverride,
  });

  static const CommunityAttributes empty = CommunityAttributes();

  int? valueOf(String key) {
    switch (key) {
      case 'pac':
        return pac;
      case 'sho':
        return sho;
      case 'pas':
        return pas;
      case 'dri':
        return dri;
      case 'def':
        return def;
      case 'phy':
        return phy;
    }
    return null;
  }

  /// Todos os 6 atributos preenchidos.
  bool get hasAllAttributes => kAttributeKeys.every((k) => valueOf(k) != null);

  bool get hasAnyAttribute => kAttributeKeys.any((k) => valueOf(k) != null);

  /// Média simples dos 6 atributos (só existe se os 6 estiverem preenchidos).
  double? get average {
    if (!hasAllAttributes) return null;
    final sum = kAttributeKeys.fold<int>(0, (acc, k) => acc + valueOf(k)!);
    return sum / kAttributeKeys.length;
  }

  /// Nota da Comunidade efetiva: override (se houver) > média dos 6 > null.
  double? get communityRating => ratingOverride ?? average;

  bool get hasCommunityRating => communityRating != null;

  factory CommunityAttributes.fromMap(Map<String, dynamic> map) {
    int? i(dynamic v) => v == null ? null : int.tryParse(v.toString());
    double? d(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return CommunityAttributes(
      pac: i(map['community_pac']),
      sho: i(map['community_sho']),
      pas: i(map['community_pas']),
      dri: i(map['community_dri']),
      def: i(map['community_def']),
      phy: i(map['community_phy']),
      ratingOverride: d(map['community_rating_override']),
    );
  }
}

/// Nota do App (0-10) -> escala 0-100.
double appRatingTo100(double appRating10) =>
    (appRating10 * 10).clamp(0.0, 100.0);

/// Overall final (inteiro 0-99).
int calculateOverall({
  required double appRating10,
  CommunityAttributes? community,
}) {
  final double app100 = appRatingTo100(appRating10);
  final double comm = (community?.communityRating ?? kCommunityNeutral)
      .clamp(0.0, 100.0);
  final double raw = app100 * kOverallAppWeight + comm * kOverallCommunityWeight;
  return raw.round().clamp(0, kOverallMax);
}

/// Nota base do app (escala 0-10) usada quando o jogador ainda não tem nota.
/// Mesmo valor de `kRatingBase` em rating_calculator.dart (duplicado aqui pra
/// este arquivo não depender do calculador de estatísticas).
const double kOverallFallbackAppRating = 7.0;

/// Overall (0-99) de um jogador a partir do mapa usado na tela da partida.
///
/// Ordem de preferência:
///   1. `overall` já gravado no snapshot do grupo (GroupBootstrap);
///   2. calcula na hora com `rating` (nota do app) + atributos `community_*`
///      presentes no próprio mapa.
/// É a ÚNICA fonte de "força" do jogador na tela da partida: tile, média do
/// time, sorteio, draft e saída/entrada de times usam isso.
double playerOverallOf(Map<String, dynamic> player) {
  final dynamic o = player['overall'];
  if (o is num) return o.toDouble();
  final dynamic r = player['rating'];
  final double app10 = r is num ? r.toDouble() : kOverallFallbackAppRating;
  final dynamic c = player['community'];
  final CommunityAttributes community = c is CommunityAttributes
      ? c
      : CommunityAttributes.fromMap(Map<String, dynamic>.from(player));
  return calculateOverall(appRating10: app10, community: community).toDouble();
}

// ─────────────────────────────────────────────────────────────
// Faixas visuais do card (bronze / prata / ouro / platina / lendária)
// ─────────────────────────────────────────────────────────────

/// Menor Overall de cada faixa (ouro até 79, platina 80-84, lendária 85+).
/// Nenhuma tela compara Overall com número solto.
const int kGoldMin = 0;
const int kPlatinumMin = 80;
const int kLegendaryMin = 85;

enum CardTier { gold, platinum, legendary }

CardTier tierForOverall(int overall) {
  if (overall >= kLegendaryMin) return CardTier.legendary;
  if (overall >= kPlatinumMin) return CardTier.platinum;
  return CardTier.gold;
}

String cardTierLabel(CardTier tier) {
  switch (tier) {
    case CardTier.legendary:
      return 'Lendária';
    case CardTier.platinum:
      return 'Platina';
    case CardTier.gold:
      return 'Ouro';
  }
}

/// Cor de destaque do Overall (usada em tiles/listas fora do card FIFA).
Color overallColor(num overall) {
  switch (tierForOverall(overall.round())) {
    case CardTier.legendary:
      return AppColors.tierLegendaryFrom;
    case CardTier.platinum:
      return AppColors.tierPlatinumBorder;
    case CardTier.gold:
      return AppColors.tierGold;
  }
}

class CardPalette {
  final List<Color> gradient;

  /// Cor do OVR/tier.
  final Color text;

  /// Cor do nome (Platina usa texto claro; os demais, o texto do tier).
  final Color nameText;

  /// Borda de 3dp integrada ao escudo (só Platina).
  final Color? border;

  /// Linha interna de 2dp (só Lendária).
  final Color? innerLine;

  /// Cor-base da textura de fundo da foto.
  final Color pattern;

  const CardPalette({
    required this.gradient,
    required this.text,
    required this.nameText,
    required this.pattern,
    this.border,
    this.innerLine,
  });
}

/// Ajusta a luminosidade (HSL) de [c] em [delta] (-1..1).
Color shiftLightness(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}

/// Gradiente vertical sutil: topo +6% de luminosidade, base -6%.
List<Color> _tierGradient(Color base) =>
    [shiftLightness(base, 0.06), base, shiftLightness(base, -0.06)];

CardPalette cardPaletteFor(CardTier tier) {
  switch (tier) {
    case CardTier.legendary:
      return CardPalette(
        gradient: [
          AppColors.tierLegendaryFrom,
          Color.lerp(AppColors.tierLegendaryFrom, AppColors.tierLegendaryTo, 0.5)!,
          AppColors.tierLegendaryTo,
        ],
        text: AppColors.tierLegendaryAccent,
        nameText: AppColors.tierLegendaryText,
        innerLine: AppColors.tierLegendaryLine,
        pattern: AppColors.tierLegendaryTo,
      );
    case CardTier.platinum:
      return CardPalette(
        gradient: _tierGradient(AppColors.tierPlatinum),
        text: AppColors.tierPlatinumBorder,
        nameText: AppColors.tierPlatinumText,
        border: AppColors.tierPlatinumBorder,
        pattern: AppColors.tierPlatinumBorder,
      );
    case CardTier.gold:
      return CardPalette(
        gradient: _tierGradient(AppColors.tierGold),
        text: AppColors.tierGoldText,
        nameText: AppColors.tierGoldText,
        pattern: AppColors.tierGold,
      );
  }
}

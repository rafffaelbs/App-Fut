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
// Faixas visuais do card (bronze / prata / ouro / elite)
// ─────────────────────────────────────────────────────────────

enum CardTier { bronze, silver, gold, elite }

CardTier cardTierFor(int overall) {
  if (overall >= 85) return CardTier.elite;
  if (overall >= 75) return CardTier.gold;
  if (overall >= 65) return CardTier.silver;
  return CardTier.bronze;
}

String cardTierLabel(CardTier tier) {
  switch (tier) {
    case CardTier.elite:
      return 'Elite';
    case CardTier.gold:
      return 'Ouro';
    case CardTier.silver:
      return 'Prata';
    case CardTier.bronze:
      return 'Bronze';
  }
}

/// Cor de destaque do Overall (usada em tiles/listas fora do card FIFA).
Color overallColor(num overall) {
  switch (cardTierFor(overall.round())) {
    case CardTier.elite:
      return AppColors.highlightGreen;
    case CardTier.gold:
      return const Color(0xFFD9A93A);
    case CardTier.silver:
      return const Color(0xFFB4BCC6);
    case CardTier.bronze:
      return const Color(0xFFC98A55);
  }
}

class CardPalette {
  final List<Color> gradient;
  final Color text;
  final Color accent;
  const CardPalette(this.gradient, this.text, this.accent);
}

CardPalette cardPaletteFor(CardTier tier) {
  switch (tier) {
    case CardTier.elite:
      return const CardPalette(
        [Color(0xFF0B3A8C), Color(0xFF001C55), Color(0xFF00072D)],
        Color(0xFFE8FFF3),
        AppColors.highlightGreen,
      );
    case CardTier.gold:
      return const CardPalette(
        [Color(0xFFF8E08E), Color(0xFFD9A93A), Color(0xFF9C6F1B)],
        Color(0xFF3B2A06),
        Color(0xFF3B2A06),
      );
    case CardTier.silver:
      return const CardPalette(
        [Color(0xFFF1F3F5), Color(0xFFB4BCC6), Color(0xFF7D8793)],
        Color(0xFF1F2933),
        Color(0xFF1F2933),
      );
    case CardTier.bronze:
      return const CardPalette(
        [Color(0xFFE0A877), Color(0xFFA9703F), Color(0xFF6B4222)],
        Color(0xFF2E1A0A),
        Color(0xFF2E1A0A),
      );
  }
}

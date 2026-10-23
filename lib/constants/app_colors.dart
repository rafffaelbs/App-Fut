import 'package:flutter/material.dart';

class AppColors {
  // ============================================================
  // PALETA PRINCIPAL SOFASCORE DARK THEME (Single Source of Truth)
  // ============================================================

  // --- Fundos e Superfícies ---
  static const deepBlue = Color(0xff0b1017);       // Fundo principal de tela (dark graphite/navy)
  static const headerBlue = Color(0xff121824);     // Superfície primária (cards, app bars, headers, placar)
  static const surfaceSubtle = Color(0xff182232);  // Superfície secundária (chips, inputs, toggles inativos)
  static const surfaceElevated = Color(0xff1e2b40);// Diálogos, popups e elementos flutuantes

  // --- Contornos e Divisores ---
  static const borderSubtle = Color(0xff222e42);   // Bordas sutis de cards e divisores
  static const borderFocused = Color(0xff3b82f6);  // Borda ao focar inputs/seleção

  // --- Acentos e Interatividade ---
  static const accentBlue = Color(0xff2563eb);     // Azul primário de ação (Royal Blue SofaScore)
  static const highlightBlue = Color(0xff3b82f6);  // Azul hover / ativo luminoso
  static const accentBlueLight = Color(0xff60a5fa);// Azul suave para badges / labels secundárias

  // --- Tipografia ---
  static const textWhite = Color(0xffffffff);      // Texto primário em destaque / números
  static const textPrimary = Color(0xfff1f5f9);    // Texto primário suave
  static const textMuted = Color(0xff94a3b8);      // Texto secundário / legendas
  static const textDim = Color(0xff64748b);        // Texto desabilitado / terciário

  // --- Status e Ações ---
  static const highlightGreen = Color(0xff00c853); // Verde clássico SofaScore (ao vivo, sucesso, notas altas)
  static const neonGreen = highlightGreen;
  static const redTeam = Color(0xffef4444);        // Vermelho time / Cartão vermelho / Acréscimo
  static const redTeamDark = Color(0xff991b1b);
  static const whiteTeam = Color(0xfff8fafc);      // Branco time Real Madrid
  static const whiteTeamBorder = Color(0xff94a3b8);
  static const goldAccent = Color(0xfff59e0b);     // Estrelas, Bola de Ouro, Avaliações ouro
  static const orangeStreak = Color(0xfff97316);   // Sequências de vitória, alertas
  static const yellowWarning = Color(0xffeab308);  // Cartão amarelo

  // --- Campo Tático ---
  static const pitchDarkGreen = Color(0xff0f2618);
  static const pitchDeepGreen = Color(0xff0a1c12);
  static const pitchLine = Color(0x6bffffff);      // Linhas do campo com 42% opacidade
  static const pitchStripeA = Color(0xff14301f);   // Listras do gramado (dessaturado)
  static const pitchStripeB = Color(0xff173826);
  static const pitchEdge = Color(0xff08120b);      // Borda / vinheta do campo

  // ============================================================
  // TOKENS DO REDESIGN (docs/design/01-cores-e-tipografia.md)
  // ============================================================

  // --- Semânticas (dessaturadas de propósito) ---
  static const success = Color(0xff22c55e);
  static const warning = yellowWarning;
  static const danger = redTeam;

  // --- Pílula de nota (fundo sólido e opaco, texto branco, sem glow) ---
  static const ratingExcellent = Color(0xff1d4ed8); // >= 8.5
  static const ratingGood = Color(0xff16a34a);      // 7.0 - 8.4
  static const ratingAverage = Color(0xffca8a04);   // 6.0 - 6.9
  static const ratingLow = Color(0xffdc2626);       // < 6.0

  static Color ratingPill(double rating) {
    if (rating >= 8.5) return ratingExcellent;
    if (rating >= 7.0) return ratingGood;
    if (rating >= 6.0) return ratingAverage;
    return ratingLow;
  }

  // --- Cores dos gráficos (ordem da rosca: lavanda, verde-água, terracota, areia, azul) ---
  static const chartGoalsAssists = Color(0xffa99ac7);
  static const chartGoals = Color(0xff6fc1b5);
  static const chartAssists = Color(0xffd98262);
  static const chartSand = Color(0xffd3c0a2);
  static const chartBlue = Color(0xff7fa6b2);
  // Variantes escuras (jogador de comparação)
  static const chartGoalsAssistsDark = Color(0xff8f7fb0);
  static const chartGoalsDark = Color(0xff55a598);
  static const chartAssistsDark = Color(0xffbb664a);

  static const chartPalette = [
    chartGoalsAssists,
    chartGoals,
    chartAssists,
    chartSand,
    chartBlue,
  ];

  // --- Tiers das cartas (fundo / texto) ---
  static const tierBronze = Color(0xff664a3d);
  static const cardShadow = Color(0xff000000);          // sombra do escudo da carta
  static const tierBronzeAccent = Color(0xffc98a55);   // destaque do OVR fora da carta
  static const tierBronzeText = Color(0xff2d1f17);
  static const tierSilver = Color(0xff9ea6b5);
  static const tierSilverText = Color(0xff1c222e);
  static const tierGold = Color(0xffd4af37);
  static const tierGoldText = Color(0xff3e2723);
  static const tierPlatinum = Color(0xff36383b);       // interior
  static const tierPlatinumBorder = Color(0xffd6a85f); // borda 3dp + OVR/posição
  static const tierPlatinumText = textPrimary;         // nome
  static const tierLegendaryFrom = Color(0xfff7f3ea);  // pérola (topo)
  static const tierLegendaryTo = Color(0xffcfc9ba);    // pérola (base)
  static const tierLegendaryText = Color(0xff1c222e);  // nome e atributos
  static const tierLegendaryAccent = Color(0xff7a6a3a); // OVR e posição
  static const tierLegendaryLine = Color(0x99ffffff);  // linha interna 2dp (60%)

  // --- Cosméticos (docs/design/07-cosmeticos.md, 7.3) ---
  static const cosmeticDiamondFrom = Color(0xffa5f3fc);
  static const cosmeticDiamond = Color(0xff22d3ee);
  static const cosmeticGoldFrom = Color(0xfffde68a);
  static const cosmeticGold = Color(0xfff59e0b);
  static const cosmeticFireFrom = Color(0xfffdba74);
  static const cosmeticFire = Color(0xfff97316);
  static const cosmeticFireIcon = Color(0xffef4444); // vermelho só no ícone
  static const cosmeticSilverFrom = Color(0xffe2e8f0);
  static const cosmeticSilverTo = Color(0xff94a3b8);
  static const cosmeticSilverFrame = Color(0xffcbd5e1);
  static const cosmeticBronzeFrom = Color(0xffe8b58a);
  static const cosmeticBronze = Color(0xffc2763e);
  static const cosmeticGoldenBallFrom = Color(0xfffde68a);
  static const cosmeticGoldenBallMid = Color(0xffd4af37);
  static const cosmeticGoldenBallTo = Color(0xffb8860b);
  static const cosmeticCrown = Color(0xfffacc15);
  static const cosmeticSapphire = Color(0xff3b6fe0);
  static const cosmeticSapphireHighlight = Color(0xff7aa2ff);
  static const cosmeticStar = Color(0xfffacc15);
  static const cosmeticNamePlate = Color(0xb30b1017); // #0B1017 a 70%

  // Aliases de compatibilidade
  static Color get tWhite => textWhite;
}



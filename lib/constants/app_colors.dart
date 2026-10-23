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

  // Aliases de compatibilidade
  static Color get tWhite => textWhite;
}



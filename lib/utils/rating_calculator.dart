import 'package:flutter/material.dart';

/// ============================================================
/// rating_calculator.dart
/// ============================================================
/// Fonte única de verdade para o cálculo de notas do app.
/// ============================================================

// --------------- Constantes públicas -------------------------

/// A nota de partida de alguém que não fez nada (nem ganhou nem perdeu).
/// Elevado para 6.5 para que a média do elenco fique em torno de 7.5.
const double kRatingBase = 6.5;

/// Impacto do Resultado
/// Aumentado para empurrar quem vence acima de 7.5 sem fazer nada especial.
const double kResultImpactWin = 1.5;
const double kResultImpactLoss = -1.5;

/// Bônus de Sequência de Vitórias (Win Streak)
const double kStreakBonus2Wins = 0.5;
const double kStreakBonus3PlusWins = 1.0;

/// Impactos Individuais
/// Mantidos para que hat-trick/3 assists ainda sejam necessários para chegar a 10.
const double kWeightGoal = 0.9;
const double kWeightAssist = 0.8;
const double kWeightOwnGoal = -1.0;

/// Impacto de Defesa (Penaliza a zaga que tomou gol)
const double kWeightConceded = -0.3;

/// Impacto Disciplinar
const double kWeightYellowCard = -1.0;
const double kWeightRedCard = -2.0;

/// Bônus Dinâmicos
const double kBonusHatTrick = 0.5; // 3 gols
const double kBonusPlaymaker = 0.5; // 3 assistências
const double kBonusTeamGoal = 0.3; // Time fez pelo menos 1 gol
const double kBonusCleanSheet =
    0.5; // Time não tomou gols (reduzido de 1.0 → evita inflação excessiva)

/// Impacto da diferença de gols (por gol de diferença)
const double kGoalDiffImpact = 0.1;

/// Limites do App
const double kMinRating = 0.0;
const double kMaxRating = 10.0;

/// --- Lógica Histórica (Bayesiana) ---
const int kBayesianPriorGames = 2;
const double kBayesianPriorRating = kRatingBase;

/// Bônus de Constância: +0.1 a cada 10 partidas.
const double kVolumeBonusPerN = 0.1;
const int kVolumeBonusEveryN = 10;

/// Mínimo para figurar no ranking Geral.
const int kMinGamesForGlobalRanking = 5;

// --------------- Funções matemáticas ----------------------------

/// Calcula a nota bruta de uma partida isolada, considerando a sequência de vitórias do time.
///
/// Com base = 6.5:
///  • Vitória sem fazer nada  → 6.5 + 1.5 + 0.3 (teamGoal) = ~8.3  (com clean sheet: ~8.8)
///  • Derrota sem fazer nada  → 6.5 - 1.5 + 0.3 - gols_conceded*0.3
///  • Só hat-trick pode chegar perto de 10 (e precisa ganhar também)
double calculateMatchRating({
  required int status,
  required int goals,
  required int assists,
  required int ownGoals,
  required int teamGoals,
  required int conceded,
  required int yellow,
  required int red,
  required int teamWinStreak,
}) {
  final double resultImpact = status == 1
      ? kResultImpactWin
      : (status == -1 ? kResultImpactLoss : 0.0);

  // Bônus de sequência (só aplica se ganhou a partida atual)
  double streakBonus = 0.0;
  if (status == 1) {
    if (teamWinStreak == 2)
      streakBonus = kStreakBonus2Wins;
    else if (teamWinStreak >= 3)
      streakBonus = kStreakBonus3PlusWins;
  }

  // Bônus Dinâmicos
  final double hatTrickBonus = goals >= 3 ? kBonusHatTrick : 0.0;
  final double playmakerBonus = assists >= 3 ? kBonusPlaymaker : 0.0;
  final double teamGoalBonus = teamGoals > 0 ? kBonusTeamGoal : 0.0;

  final double attackImpact =
      (goals * kWeightGoal) +
      (assists * kWeightAssist) +
      (ownGoals * kWeightOwnGoal) +
      hatTrickBonus +
      playmakerBonus +
      teamGoalBonus;

  final double defenseImpact = conceded * kWeightConceded;
  final double disciplineImpact =
      (yellow * kWeightYellowCard) + (red * kWeightRedCard);

  // Impacto da diferença de gols: bônus para quem ganhou, baque para quem perdeu
  final int goalDiff = (teamGoals - conceded).abs();
  double goalDiffImpact = 0.0;
  if (status == 1)
    goalDiffImpact = goalDiff * kGoalDiffImpact;
  else if (status == -1)
    goalDiffImpact = -goalDiff * kGoalDiffImpact;

  double raw =
      kRatingBase +
      resultImpact +
      streakBonus +
      attackImpact +
      defenseImpact +
      disciplineImpact +
      goalDiffImpact;

  // Clean sheet: apenas vitória ou empate (não punir quem perdeu mas não tomou gols)
  if (conceded == 0 && status >= 0) {
    raw += kBonusCleanSheet;
  }

  return raw.clamp(kMinRating, kMaxRating);
}

/// Calcula a nota bruta de um Goleiro numa partida.
double calculateGkMatchRating({
  required int status,
  required int goals,
  required int assists,
  required int conceded,
  required int yellow,
  required int red,
  required int teamWinStreak,
}) {
  final double resultImpact =
      status == 1 ? kResultImpactWin : (status == -1 ? kResultImpactLoss : 0.0);

  double streakBonus = 0.0;
  if (status == 1) {
    if (teamWinStreak == 2) streakBonus = kStreakBonus2Wins;
    else if (teamWinStreak >= 3) streakBonus = kStreakBonus3PlusWins;
  }

  final double attackImpact = (goals * kWeightGoal) + (assists * kWeightAssist);

  // Goleiros são penalizados mais fortemente por cada gol sofrido
  const double gkWeightConceded = -0.5;
  final double defenseImpact = conceded * gkWeightConceded;

  final double disciplineImpact = (yellow * kWeightYellowCard) + (red * kWeightRedCard);

  double raw = kRatingBase + resultImpact + streakBonus + attackImpact + defenseImpact + disciplineImpact;

  // Clean sheet bônus reforçado para goleiros
  if (conceded == 0 && status >= 0) {
    raw += 1.5;
  }

  return raw.clamp(kMinRating, kMaxRating);
}

/// Calcula a Média Final.
/// [useBayesian] = true  → ranking global (com prior bayesiano e bônus de volume).
/// [useBayesian] = false → ranking de pelada (média aritmética simples).
double calculateFinalRating({
  required List<double> ratings,
  bool useBayesian = true,
}) {
  final int games = ratings.length;
  if (games == 0) return kRatingBase;

  if (!useBayesian) {
    // Média aritmética simples — usada no ranking da pelada (session ranking)
    final double sum = ratings.fold(0.0, (acc, r) => acc + r);
    return (sum / games).clamp(kMinRating, kMaxRating);
  }

  // Média ponderada com peso 2× para as 3 últimas partidas
  double weightedSum = 0.0;
  double totalWeight = 0.0;

  for (int i = 0; i < games; i++) {
    final double weight = (i >= games - 3) ? 2.0 : 1.0;
    weightedSum += ratings[i] * weight;
    totalWeight += weight;
  }

  final double bayesianRating =
      ((kBayesianPriorGames * kBayesianPriorRating) + weightedSum) /
      (kBayesianPriorGames + totalWeight);

  final double volumeBonus = (games ~/ kVolumeBonusEveryN) * kVolumeBonusPerN;

  return (bayesianRating + volumeBonus).clamp(kMinRating, kMaxRating);
}

// --------------- Funções Visuais (Cores e Labels) ----------------------------

Color getRatingColor(double rating) {
  if (rating >= 9.0) return Colors.purpleAccent; // Mitou
  if (rating >= 8.0) return Colors.green[700]!; // Joga D+
  if (rating >= 7.0) return Colors.green; // Bom
  if (rating >= 6.0) return Colors.lightGreenAccent; // Médio
  if (rating >= 5.0) return Colors.yellow; // Abaixo
  if (rating >= 4.0) return Colors.orange; // Bagre
  return Colors.red; // Pior do mundo
}

String getRatingLabel(double rating, int games) {
  if (games < 5) return 'Estreante';
  if (rating >= 9.0) return 'BallonDor';
  if (rating >= 8.0) return 'Elite';
  if (rating >= 7.0) return 'Ótimo';
  if (rating >= 6.0) return 'Bom';
  if (rating >= 5.0) return 'Regular';
  return 'Abaixo';
}

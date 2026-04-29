import 'package:flutter/material.dart';

/// ============================================================
/// rating_calculator.dart
/// ============================================================
/// Fonte única de verdade para o cálculo de notas do app.
/// ============================================================

// --------------- Constantes públicas -------------------------

/// A nota de partida de alguém que não fez nada (nem ganhou nem perdeu)
const double kRatingBase = 7.0;

/// Impacto do Resultado 
const double kResultImpactWin  =  1.5;
const double kResultImpactLoss = -1.5;

/// Bônus de Sequência de Vitórias (Win Streak)
const double kStreakBonus2Wins = 0.5;
const double kStreakBonus3PlusWins = 1.0;

/// Impactos Individuais
const double kWeightGoal       =  1.5; 
const double kWeightAssist     =  1.0;
const double kWeightOwnGoal    = -1.0;

/// Impacto de Defesa (Penaliza a zaga que tomou gol)
const double kWeightConceded   = -0.3; 

/// Impacto Disciplinar
const double kWeightYellowCard = -1.0;
const double kWeightRedCard    = -2.0;

/// Bônus Dinâmicos
const double kBonusHatTrick    = 1.0;
const double kBonusPlaymaker   = 1.0; // 3 assists
const double kBonusTeamGoal    = 0.5; // Time fez pelo menos 1 gol

/// Limites do App
const double kMinRating = 0.0;
const double kMaxRating = 10.0;

/// --- Lógica Histórica (Bayesiana) ---
const int    kBayesianPriorGames  = 2;
const double kBayesianPriorRating = kRatingBase;

/// Bônus de Constância: +0.1 a cada 10 partidas.
const double kVolumeBonusPerN = 0.1;
const int    kVolumeBonusEveryN = 10;

/// Mínimo para figurar no ranking Geral.
const int kMinGamesForGlobalRanking = 5;

// --------------- Funções matemáticas ----------------------------

/// Calcula a nota bruta de uma partida isolada, considerando a sequência de vitórias do time.
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
  final double resultImpact =
      status == 1 ? kResultImpactWin : (status == -1 ? kResultImpactLoss : 0.0);

  // Calcula o bônus de sequência (só aplica se ganhou a partida atual)
  double streakBonus = 0.0;
  if (status == 1) {
    if (teamWinStreak == 2) streakBonus = kStreakBonus2Wins;
    else if (teamWinStreak >= 3) streakBonus = kStreakBonus3PlusWins;
  }

  // Bônus Dinâmicos
  double hatTrickBonus = goals >= 3 ? kBonusHatTrick : 0.0;
  double playmakerBonus = assists >= 3 ? kBonusPlaymaker : 0.0;
  double teamGoalBonus = teamGoals > 0 ? kBonusTeamGoal : 0.0;

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

  final double raw = kRatingBase + resultImpact + streakBonus + attackImpact + defenseImpact + disciplineImpact;
  
  return raw.clamp(kMinRating, kMaxRating);
}

/// Calcula a Média Geral Histórica.
double calculateFinalRating({
  required double sumRatings,
  required int games,
}) {
  if (games == 0) return kRatingBase;

  final double bayesianRating =
      ((kBayesianPriorGames * kBayesianPriorRating) + sumRatings) /
      (kBayesianPriorGames + games);

  final double volumeBonus = (games ~/ kVolumeBonusEveryN) * kVolumeBonusPerN;

  return (bayesianRating + volumeBonus).clamp(kMinRating, kMaxRating);
}

// --------------- Funções Visuais (Cores e Labels) ----------------------------

Color getRatingColor(double rating) {
  if (rating >= 9.0) return Colors.purpleAccent; // Mitou
  if (rating >= 8.0) return Colors.green[700]!;  // Joga D+
  if (rating >= 7.0) return Colors.green;        // Bom
  if (rating >= 6.0) return Colors.lightGreenAccent; // Médio
  if (rating >= 5.0) return Colors.yellow;       // Abaixo
  if (rating >= 4.0) return Colors.orange;       // Bagre
  return Colors.red;                             // Pior do mundo
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

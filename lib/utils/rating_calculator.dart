import 'package:flutter/material.dart';

/// ============================================================
/// rating_calculator.dart
/// ============================================================
/// Single source of truth for the app's rating calculation.
/// ============================================================

// --------------- Public constants -------------------------

/// The match rating for someone who did nothing (neither won nor lost).
/// Lowered to 6.0 to avoid rating inflation.
const double kRatingBase = 6.0;

/// Impacto do Resultado
/// Raised to 0.8 to reward winning and produce more high ratings (9 and 10).
const double kResultImpactWin  =  0.8;
const double kResultImpactLoss = -0.5;

/// Win Streak Bonus
const double kStreakBonus2Wins     = 0.2;
const double kStreakBonus3PlusWins = 0.4;

/// Impactos Individuais
const double kWeightGoal       =  1.0;
const double kWeightAssist     =  0.8;
const double kWeightOwnGoal    = -1.0;

/// Impacto de Defesa
const double kWeightConceded   = -0.1;

/// Impacto Disciplinar
const double kWeightYellowCard = -0.5;
const double kWeightRedCard    = -1.5;

/// Dynamic Bonuses
const double kBonusHatTrick    = 0.75;  // 3 gols
const double kBonusPlaymaker   = 0.85;  // 3 assistências
const double kBonusTeamGoal    = 0.1;   // Removido para evitar inflação passiva
const double kBonusCleanSheet  = 0.2;   // Bônus menor para clean sheet geral

/// Impact of the goal difference (per goal of difference)
const double kGoalDiffImpact   = 0.05;

/// Limites do App
const double kMinRating = 0.0;
const double kMaxRating = 10.0;

/// --- Historical (Bayesian) Logic ---
const int    kBayesianPriorGames  = 2;
const double kBayesianPriorRating = kRatingBase;

/// Consistency Bonus: +0.15 every 5 matches.
/// This speeds up regular players toward a 9 or 10 rating.
const double kVolumeBonusPerN   = 0.15;
const int    kVolumeBonusEveryN = 5;

/// Minimum to appear on the Overall ranking.
const int kMinGamesForGlobalRanking = 5;

// --------------- Math functions ----------------------------

/// Calculates the raw rating for a single match, factoring in the team's win streak.
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
  double? teamAvgRating,
  double? opponentAvgRating,
}) {
  double resultImpact =
      status == 1 ? kResultImpactWin : (status == -1 ? kResultImpactLoss : 0.0);

  // Elo-Lite Asymmetric Pressure generalizada
  double positiveMultiplier = 1.0;
  double negativeMultiplier = 1.0;

  if (teamAvgRating != null && opponentAvgRating != null) {
    final double diff = teamAvgRating - opponentAvgRating;
    final double factor = (diff.abs() * 0.5).clamp(0.0, 1.0); // Limitado a 1.0
    
    if (diff < 0) {
      // Underdog (Time mais fraco)
      positiveMultiplier = 1.0 + factor; 
      negativeMultiplier = 1.0 / (1.0 + factor); 
    } else if (diff > 0) {
      // Favorito (Time mais forte)
      positiveMultiplier = 1.0 / (1.0 + factor); 
      negativeMultiplier = 1.0 + factor; 
    }
  }

  if (resultImpact > 0) resultImpact *= positiveMultiplier;
  else if (resultImpact < 0) resultImpact *= negativeMultiplier;

  // Streak bonus (only applies if the current match was won)
  double streakBonus = 0.0;
  if (status == 1) {
    if (teamWinStreak == 2)      streakBonus = kStreakBonus2Wins * positiveMultiplier;
    else if (teamWinStreak >= 3) streakBonus = kStreakBonus3PlusWins * positiveMultiplier;
  }

  // Dynamic Bonuses
  final double hatTrickBonus   = goals   >= 3 ? kBonusHatTrick   : 0.0;
  final double playmakerBonus  = assists >= 3 ? kBonusPlaymaker  : 0.0;
  final double teamGoalBonus   = teamGoals > 0 ? kBonusTeamGoal  : 0.0;

  double attackImpact =
      (goals   * kWeightGoal)   +
      (assists * kWeightAssist) +
      (ownGoals * kWeightOwnGoal) +
      hatTrickBonus +
      playmakerBonus +
      teamGoalBonus;
      
  // Aplica multiplicador
  if (attackImpact > 0) attackImpact *= positiveMultiplier;
  else if (attackImpact < 0) attackImpact *= negativeMultiplier;

  double defenseImpact = conceded * kWeightConceded;
  defenseImpact *= negativeMultiplier;

  double disciplineImpact = (yellow * kWeightYellowCard) + (red * kWeightRedCard);
  disciplineImpact *= negativeMultiplier;

  // Impact of the goal difference: bonus for the winner, hit for the loser
  final int goalDiff = (teamGoals - conceded).abs();
  double goalDiffImpact = 0.0;
  if (status == 1) {
      goalDiffImpact = (goalDiff * kGoalDiffImpact) * positiveMultiplier;
  } else if (status == -1) {
      goalDiffImpact = (-goalDiff * kGoalDiffImpact) * negativeMultiplier;
  }

  double raw = kRatingBase +
      resultImpact +
      streakBonus +
      attackImpact +
      defenseImpact +
      disciplineImpact +
      goalDiffImpact;

  // Clean sheet: only on a win or draw (don't punish a loss with no goals conceded)
  if (conceded == 0 && status >= 0) {
    raw += (kBonusCleanSheet * positiveMultiplier);
  }

  return raw.clamp(kMinRating, kMaxRating);
}

/// Calculates the raw rating for a Goalkeeper in a match.
double calculateGkMatchRating({
  required int status,
  required int goals,
  required int assists,
  required int conceded,
  required int yellow,
  required int red,
  required int teamWinStreak,
  double? teamAvgRating,
  double? opponentAvgRating,
}) {
  // The goalkeeper is doing everyone a favor by playing in goal. They aren't judged by win or loss.
  double resultImpact = 0.0;

  // Elo-Lite Asymmetric Pressure generalizada (mantida apenas para Gols/Assists do goleiro)
  double positiveMultiplier = 1.0;
  double negativeMultiplier = 1.0;

  if (teamAvgRating != null && opponentAvgRating != null) {
    final double diff = teamAvgRating - opponentAvgRating;
    final double factor = (diff.abs() * 0.5).clamp(0.0, 1.0);
    
    if (diff < 0) {
      // Underdog (Time mais fraco)
      positiveMultiplier = 1.0 + factor; 
      negativeMultiplier = 1.0 / (1.0 + factor); 
    } else if (diff > 0) {
      // Favorito (Time mais forte)
      positiveMultiplier = 1.0 / (1.0 + factor); 
      negativeMultiplier = 1.0 + factor; 
    }
  }

  // No streak bonus for goalkeepers (since winning doesn't matter here)
  double streakBonus = 0.0;

  double attackImpact = (goals * kWeightGoal) + (assists * kWeightAssist);
  if (attackImpact > 0) attackImpact *= positiveMultiplier;

  // Goalkeepers get a minimal penalty for goals conceded, since they depend a lot on the defense.
  const double gkWeightConceded = -0.1;
  double defenseImpact = conceded * gkWeightConceded;
  defenseImpact *= negativeMultiplier;

  double disciplineImpact = (yellow * kWeightYellowCard) + (red * kWeightRedCard);
  disciplineImpact *= negativeMultiplier;

  double raw = kRatingBase + resultImpact + streakBonus + attackImpact + defenseImpact + disciplineImpact;

  // Reinforced clean sheet bonus for goalkeepers
  if (conceded == 0 && status >= 0) {
    raw += (0.8 * positiveMultiplier);
  }

  return raw.clamp(kMinRating, kMaxRating);
}

/// Calculates the Final Average
/// [useEMA] = false -> Pickup Game Ranking (Day): Simple Arithmetic Average.
/// [useEMA] = true  -> Global Ranking: Bayesian Average to require a volume of games.
double calculateFinalRating({
  required List<double> ratings,
  bool useEMA = true, // Funciona como flag para o Ranking Global
}) {
  final int games = ratings.length;
  if (games == 0) return kRatingBase;

  final double sum = ratings.fold(0.0, (acc, r) => acc + r);

  if (!useEMA) {
    // Day ranking (Simple Average)
    return (sum / games).clamp(kMinRating, kMaxRating);
  }

  // Global Ranking (Bayesian Average + Consistency)
  // Ultra-light initial anchor. 
  // Reduzido para apenas 3 jogos para liberar as notas altas (9 e 10) rapidamente para quem jogar muito bem.
  const int priorGames = 3; 
  final double bayesianAvg = (sum + (priorGames * kRatingBase)) / (games + priorGames);

  // Small consistency bonus (game volume)
  double finalRating = bayesianAvg + ((games ~/ kVolumeBonusEveryN) * kVolumeBonusPerN);

  return finalRating.clamp(kMinRating, kMaxRating);
}

// --------------- Visual Functions (Colors and Labels) ----------------------------

Color getRatingColor(double rating) {
  if (rating >= 9.0) return Colors.purpleAccent;    // Mitou
  if (rating >= 8.0) return Colors.green[700]!;     // Joga D+
  if (rating >= 7.0) return Colors.green;           // Bom
  if (rating >= 6.0) return Colors.lightGreenAccent;// Médio
  if (rating >= 5.0) return Colors.yellow;          // Abaixo
  if (rating >= 4.0) return Colors.orange;          // Bagre
  return Colors.red;                                // Pior do mundo
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

import 'package:flutter/material.dart';

/// ============================================================
/// rating_calculator.dart
/// ============================================================
/// Fonte única de verdade para o cálculo de notas do app.
/// ============================================================

// --------------- Constantes públicas -------------------------

/// A nota de partida de alguém que não fez nada (nem ganhou nem perdeu).
/// Abaixado para 6.0 para evitar a inflação de notas.
const double kRatingBase = 6.0;

/// Impacto do Resultado
/// Reduzido para evitar que a vitória por si só dê notas absurdas.
const double kResultImpactWin  =  0.5;
const double kResultImpactLoss = -0.5;

/// Bônus de Sequência de Vitórias (Win Streak)
const double kStreakBonus2Wins     = 0.2;
const double kStreakBonus3PlusWins = 0.4;

/// Impactos Individuais
const double kWeightGoal       =  0.8;
const double kWeightAssist     =  0.6;
const double kWeightOwnGoal    = -1.0;

/// Impacto de Defesa
const double kWeightConceded   = -0.1;

/// Impacto Disciplinar
const double kWeightYellowCard = -0.5;
const double kWeightRedCard    = -1.5;

/// Bônus Dinâmicos
const double kBonusHatTrick    = 0.75;  // 3 gols
const double kBonusPlaymaker   = 0.85;  // 3 assistências
const double kBonusTeamGoal    = 0.0;   // Removido para evitar inflação passiva
const double kBonusCleanSheet  = 0.2;   // Bônus menor para clean sheet geral

/// Impacto da diferença de gols (por gol de diferença)
const double kGoalDiffImpact   = 0.05;

/// Limites do App
const double kMinRating = 0.0;
const double kMaxRating = 10.0;

/// --- Lógica Histórica (Bayesiana) ---
const int    kBayesianPriorGames  = 2;
const double kBayesianPriorRating = kRatingBase;

/// Bônus de Constância: +0.1 a cada 10 partidas.
const double kVolumeBonusPerN   = 0.1;
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

  // Bônus de sequência (só aplica se ganhou a partida atual)
  double streakBonus = 0.0;
  if (status == 1) {
    if (teamWinStreak == 2)      streakBonus = kStreakBonus2Wins * positiveMultiplier;
    else if (teamWinStreak >= 3) streakBonus = kStreakBonus3PlusWins * positiveMultiplier;
  }

  // Bônus Dinâmicos
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

  // Impacto da diferença de gols: bônus para quem ganhou, baque para quem perdeu
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

  // Clean sheet: apenas vitória ou empate (não punir quem perdeu mas não tomou gols)
  if (conceded == 0 && status >= 0) {
    raw += (kBonusCleanSheet * positiveMultiplier);
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
  double? teamAvgRating,
  double? opponentAvgRating,
}) {
  // O goleiro faz um favor indo no gol. Ele não é julgado por vitória ou derrota.
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

  // Sem bônus de sequência para goleiros (pois vitória não importa)
  double streakBonus = 0.0;

  double attackImpact = (goals * kWeightGoal) + (assists * kWeightAssist);
  if (attackImpact > 0) attackImpact *= positiveMultiplier;

  // Goleiros têm punição mínima por gols sofridos, pois dependem muito da zaga.
  const double gkWeightConceded = -0.1;
  double defenseImpact = conceded * gkWeightConceded;
  defenseImpact *= negativeMultiplier;

  double disciplineImpact = (yellow * kWeightYellowCard) + (red * kWeightRedCard);
  disciplineImpact *= negativeMultiplier;

  double raw = kRatingBase + resultImpact + streakBonus + attackImpact + defenseImpact + disciplineImpact;

  // Clean sheet bônus reforçado para goleiros
  if (conceded == 0 && status >= 0) {
    raw += (0.8 * positiveMultiplier);
  }

  return raw.clamp(kMinRating, kMaxRating);
}

/// Calcula a Média Final
/// [useEMA] = false -> Ranking da Pelada (Dia): Média Aritmética Simples.
/// [useEMA] = true  -> Ranking Global: Média Bayesiana para exigir volume de jogos.
double calculateFinalRating({
  required List<double> ratings,
  bool useEMA = true, // Funciona como flag para o Ranking Global
}) {
  final int games = ratings.length;
  if (games == 0) return kRatingBase;

  final double sum = ratings.fold(0.0, (acc, r) => acc + r);

  if (!useEMA) {
    // Ranking do dia (Média Simples)
    return (sum / games).clamp(kMinRating, kMaxRating);
  }

  // Ranking Global (Média Bayesiana + Constância)
  // Âncora inicial para forçar o crescimento gradual (30 a 60 jogos para estabilizar a nota real)
  const int priorGames = 15; 
  final double bayesianAvg = (sum + (priorGames * kRatingBase)) / (games + priorGames);

  // Pequeno bônus de constância (volume de jogo)
  double finalRating = bayesianAvg + ((games ~/ kVolumeBonusEveryN) * kVolumeBonusPerN);

  return finalRating.clamp(kMinRating, kMaxRating);
}

// --------------- Funções Visuais (Cores e Labels) ----------------------------

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

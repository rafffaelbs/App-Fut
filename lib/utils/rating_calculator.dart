/// ============================================================
/// rating_calculator.dart
/// ============================================================
/// Fonte única de verdade para o cálculo de notas do app.
///
/// PESOS DOS EVENTOS (por partida):
///   Resultado vitória          : +1.50
///   Resultado derrota          : -1.50
///   Resultado empate           :  0.00
///   Gol marcado                : +1.40
///   Assistência                : +0.80
///   Gol contra                 : -1.00
///   Gol sofrido (pelo time)    : -0.40 por gol
///   Cartão amarelo             : -0.50
///   Cartão vermelho            : -1.30
///
/// ESCALA DE NOTA FINAL:
///   Performance neutra (base)  :  5.0
///   Range real                 :  0.0 – 10.0
///   3 gols / 0 levados / vitória  → ~10.0
///   0 participações / 3 levados / derrota → ~0.0
///
/// NOTA HISTÓRICA (bayesiana):
///   Prior: 5 jogos com nota base 5.0
///   Bônus de volume: +0.1 a cada 15 jogos
///   Mínimo de jogos para o ranking geral: 5
/// ============================================================

// --------------- Constantes públicas -------------------------

/// Nota de um jogador que nunca jogou (prior / base neutra).
const double kRatingBase = 6.0;

/// Peso aplicado ao resultado da partida (vitória/derrota).
const double kResultImpactWin  =  2.50;
const double kResultImpactLoss = -1.70;

/// Pesos de eventos individuais.
const double kWeightGoal       =  2.00;
const double kWeightAssist     =  1.25;
const double kWeightOwnGoal    = -1.00;
const double kWeightConceded   = -0.50; // por gol levado pelo time
const double kWeightYellowCard = -0.60;
const double kWeightRedCard    = -1.50;

/// Parâmetros da escala final.
/// A nota bruta (base + performance) é mapeada para [kMinRating, kMaxRating].
const double kMinRating = 0.0;
const double kMaxRating = 10.0;

/// Parâmetros bayesianos para a nota histórica.
const int    kBayesianPriorGames  = 5;
const double kBayesianPriorRating = kRatingBase;

/// Bônus de longevidade: +0.1 a cada N jogos.
const double kVolumeBonusPerN = 0.1;
const int    kVolumeBonusEveryN = 15;

/// Mínimo de jogos para aparecer no ranking **geral** (group_ranking).
const int kMinGamesForGlobalRanking = 5;

// --------------- Funções públicas ----------------------------

/// Calcula a nota bruta de uma única partida.
///
/// [status]   : 1 = vitória, 0 = empate, -1 = derrota
/// [goals]    : gols marcados
/// [assists]  : assistências
/// [ownGoals] : gols contra
/// [conceded] : gols que o time do jogador levou
/// [yellow]   : cartões amarelos
/// [red]      : cartões vermelhos
///
/// Retorna um valor já limitado a [kMinRating, kMaxRating].
double calculateMatchRating({
  required int status,
  required int goals,
  required int assists,
  required int ownGoals,
  required int conceded,
  required int yellow,
  required int red,
}) {
  final double resultImpact =
      status == 1 ? kResultImpactWin : (status == -1 ? kResultImpactLoss : 0.0);

  final double attackImpact =
      (goals * kWeightGoal) +
      (assists * kWeightAssist) +
      (ownGoals * kWeightOwnGoal);

  final double defenseImpact = conceded * kWeightConceded;

  final double disciplineImpact =
      (yellow * kWeightYellowCard) + (red * kWeightRedCard);

  final double performance =
      resultImpact + (attackImpact*2.0) + (defenseImpact*1.5) + disciplineImpact;

  final double raw = kRatingBase + (performance * 5.0);
  return raw.clamp(kMinRating, kMaxRating);
}

/// Calcula a nota histórica final de um jogador a partir da soma
/// de notas brutas e do número de partidas.
///
/// Aplica média bayesiana (suavização para poucos jogos)
/// e bônus de volume por longevidade.
///
/// Retorna um valor limitado a [kMinRating, kMaxRating].
double calculateFinalRating({
  required double sumRatings,
  required int games,
}) {
  if (games == 0) return kRatingBase;

  // Média bayesiana: atenua extremos quando o jogador tem poucos jogos.
  final double bayesianRating =
      ((kBayesianPriorGames * kBayesianPriorRating) + sumRatings) /
      (kBayesianPriorGames + games);

  // Bônus de longevidade: recompensa presença constante.
  final double volumeBonus = (games ~/ kVolumeBonusEveryN) * kVolumeBonusPerN;

  return (bayesianRating + volumeBonus).clamp(kMinRating, kMaxRating);
}

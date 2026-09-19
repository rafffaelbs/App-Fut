import 'package:flutter/material.dart';

/// ============================================================
/// rating_calculator.dart
/// ============================================================
/// Single source of truth for the app's rating calculation.
///
/// v2: revisado pra reduzir dois problemas do v1:
///   1) Ballon d'Or demais -- bônus empilhavam sem teto e o multiplicador
///      de zebra chegava a 2x, então uma partida boa virava nota 9+ fácil.
///   2) Gente presa em nota baixa a temporada toda -- a nota "geral" era
///      uma média histórica de todos os jogos, então um começo ruim virava
///      uma âncora que quase não soltava.
/// ============================================================

// --------------- Public constants -------------------------

/// The match rating for someone who did nothing (neither won nor lost).
const double kRatingBase = 6.0;

/// Impacto do Resultado
const double kResultImpactWin  =  0.8;
const double kResultImpactLoss = -0.5;

/// Win Streak Bonus
const double kStreakBonus2Wins     = 0.2;
const double kStreakBonus3PlusWins = 0.4;

/// Impactos Individuais (valor do 1º gol/assistência; os seguintes têm
/// retorno decrescente -- ver [_diminishingImpact]).
const double kWeightGoal       =  1.0;
const double kWeightAssist     =  0.8;
const double kWeightOwnGoal    = -1.0;

/// Fator de decaimento aplicado a cada gol/assistência extra na mesma
/// partida (0.6 = cada um vale 60% do anterior). Evita que uma goleada
/// pessoal sozinha estoure a nota via soma linear.
const double kDiminishingDecay = 0.8;

/// Impacto de Defesa
const double kWeightConceded   = -0.1;

/// Impacto Disciplinar
const double kWeightYellowCard = -0.5;
const double kWeightRedCard    = -1.5;

/// Dynamic Bonuses (menores que antes -- o ganho principal de hat-trick/
/// playmaker já vem do próprio [_diminishingImpact]; isso aqui é só um
/// "selo" simbólico por bater a marca).
const double kBonusHatTrick    = 0.3;   // 3+ gols
const double kBonusPlaymaker   = 0.35;  // 3+ assistências
const double kBonusTeamGoal    = 0.1;   // Ativado para ajudar aqueles que ajudaram mas nao puderam nem fazer gol ou assist.
const double kBonusCleanSheet  = 0.2;   // Bônus menor para clean sheet geral

/// Impact of the goal difference (per goal of difference)
const double kGoalDiffImpact   = 0.1;

/// Teto de variação por partida em torno da base (kRatingBase). Serve só
/// de rede de segurança contra bug/soma maluca -- quem realmente segura
/// a nota entre 0 e 10 é o clamp final. Propositalmente alto (acima do
/// que dá pra atingir com clamp(0,10) já em vigor) pra não impedir uma
/// partida perfeita de bater 10: com kRatingBase = 6.0, o delta máximo
/// "útil" já é 4.0 (pra chegar em 10) e o mínimo é -6.0 (pra chegar em 0).
const double kMaxDeltaUp   =  6.0;
const double kMaxDeltaDown = -7.0;

/// Bônus por gol da virada: o gol que faz o time, que estava perdendo,
/// assumir a frente PELA PRIMEIRA VEZ na partida. Único por partida.
const double kBonusComebackGoal = 0.4;

/// Bônus por gol decisivo nos minutos finais: dentro da janela final do
/// jogo (ver [kClutchWindowFraction]), num jogo apertado (diferença de
/// até 1 gol antes dele), que garante vitória ou empate pra quem marcou.
/// Único por partida (só o último gol do jogo pode ser o "decisivo").
const double kBonusClutchGoal = 0.4;

/// Limites do App
const double kMinRating = 0.0;
const double kMaxRating = 10.0;

/// --- Nota "geral" (perfil/ranking) ---
/// Em vez de média histórica de todos os jogos, usa só a forma recente:
/// média das últimas [kFormWindowGames] partidas. Assim a nota reflete a
/// fase atual do jogador -- um mês ruim não vira condenação pro ano
/// inteiro, e uma fase boa antiga não fica carregada pra sempre.
const int kFormWindowGames = 12;

/// Com menos que isso de jogos no total, a nota é amortecida em direção à
/// base -- evita que 1 ou 2 partidas isoladas (boas ou ruins) já mostrem
/// uma nota extrema no perfil do jogador.
const int kFormAnchorGames = 3;

/// Minimum to appear on the Overall ranking.
const int kMinGamesForGlobalRanking = 5;

/// Duração regulamentar padrão de uma partida, em segundos (usada só como
/// referência pra achar a "janela final" do jogo pro bônus de gol
/// decisivo -- não conta prorrogação).
const int kRegulationSeconds = 480;

/// Fração final do tempo regulamentar considerada "minutos finais" pro
/// bônus de gol decisivo (0.2 = últimos 20% do jogo).
const double kClutchWindowFraction = 0.2;

// --------------- Math functions ----------------------------

/// Soma o impacto de uma contagem de eventos (gols, assistências) com
/// retorno decrescente: o 1º vale [base], os seguintes valem [base] *
/// kDiminishingDecay^n. Assim uma partida com muitos gols ainda é
/// claramente premiada, mas sem crescer linearmente sem limite.
double _diminishingImpact(int count, double base) {
  double total = 0.0;
  double value = base;
  for (int i = 0; i < count; i++) {
    total += value;
    value *= kDiminishingDecay;
  }
  return total;
}

/// Calcula o multiplicador de pressão (zebra ganhando vale mais, favorito
/// ganhando vale menos -- e o inverso nas perdas), agora com teto reduzido
(double positive, double negative) _pressureMultipliers(
  double? teamAvgRating,
  double? opponentAvgRating,
) {
  if (teamAvgRating == null || opponentAvgRating == null) return (1.0, 1.0);

  final double diff = teamAvgRating - opponentAvgRating;
  final double factor = (diff.abs() * 0.15).clamp(0.0, 0.5);

  if (diff < 0) {
    // Underdog (time mais fraco)
    return (1.0 + factor, 1.0 / (1.0 + factor));
  } else if (diff > 0) {
    // Favorito (time mais forte)
    return (1.0 / (1.0 + factor), 1.0 + factor);
  }
  return (1.0, 1.0);
}

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
  bool scoredComebackGoal = false,
  bool scoredClutchGoal = false,
}) {
  double resultImpact =
      status == 1 ? kResultImpactWin : (status == -1 ? kResultImpactLoss : 0.0);

  final (positiveMultiplier, negativeMultiplier) =
      _pressureMultipliers(teamAvgRating, opponentAvgRating);

  if (resultImpact > 0) resultImpact *= positiveMultiplier;
  else if (resultImpact < 0) resultImpact *= negativeMultiplier;

  // Streak bonus (only applies if the current match was won)
  double streakBonus = 0.0;
  if (status == 1) {
    if (teamWinStreak == 2)      streakBonus = kStreakBonus2Wins * positiveMultiplier;
    else if (teamWinStreak >= 3) streakBonus = kStreakBonus3PlusWins * positiveMultiplier;
  }

  // Gols/assistências com retorno decrescente + selo simbólico de marco
  final double hatTrickBonus  = goals   >= 3 ? kBonusHatTrick  : 0.0;
  final double playmakerBonus = assists >= 3 ? kBonusPlaymaker : 0.0;
  final double teamGoalBonus  = teamGoals > 0 ? kBonusTeamGoal : 0.0; // desativado (0.0)

  double attackImpact =
      _diminishingImpact(goals, kWeightGoal) +
      _diminishingImpact(assists, kWeightAssist) +
      (ownGoals * kWeightOwnGoal) +
      hatTrickBonus +
      playmakerBonus +
      teamGoalBonus;

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

  double cleanSheetBonus = 0.0;
  // Clean sheet: only on a win or draw (don't punish a loss with no goals conceded)
  if (conceded == 0 && status >= 0) {
    cleanSheetBonus = kBonusCleanSheet * positiveMultiplier;
  }

  // Bônus de eventos especiais -- flat, não passam pelo multiplicador de
  // pressão (são "feitos", não dependem de quem é favorito ou zebra).
  final double comebackBonus = scoredComebackGoal ? kBonusComebackGoal : 0.0;
  final double clutchBonus   = scoredClutchGoal   ? kBonusClutchGoal   : 0.0;

  double delta = resultImpact +
      streakBonus +
      attackImpact +
      defenseImpact +
      disciplineImpact +
      goalDiffImpact +
      cleanSheetBonus +
      comebackBonus +
      clutchBonus;

  // Rede de segurança -- só evita soma absurda; quem define o range real
  // é o clamp(kMinRating, kMaxRating) logo abaixo.
  delta = delta.clamp(kMaxDeltaDown, kMaxDeltaUp);

  return (kRatingBase + delta).clamp(kMinRating, kMaxRating);
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
  const double resultImpact = 0.0;

  final (positiveMultiplier, negativeMultiplier) =
      _pressureMultipliers(teamAvgRating, opponentAvgRating);

  // No streak bonus for goalkeepers (since winning doesn't matter here)
  const double streakBonus = 0.0;

  double attackImpact =
      _diminishingImpact(goals, kWeightGoal) +
      _diminishingImpact(assists, kWeightAssist);
  if (attackImpact > 0) attackImpact *= positiveMultiplier;

  // Goalkeepers get a minimal penalty for goals conceded, since they depend a lot on the defense.
  const double gkWeightConceded = -0.1;
  double defenseImpact = conceded * gkWeightConceded;
  defenseImpact *= negativeMultiplier;

  double disciplineImpact = (yellow * kWeightYellowCard) + (red * kWeightRedCard);
  disciplineImpact *= negativeMultiplier;

  double cleanSheetBonus = 0.0;
  // Reinforced clean sheet bonus for goalkeepers
  if (conceded == 0 && status >= 0) {
    cleanSheetBonus = 0.8 * positiveMultiplier;
  }

  double delta = resultImpact + streakBonus + attackImpact + defenseImpact +
      disciplineImpact + cleanSheetBonus;
  delta = delta.clamp(kMaxDeltaDown, kMaxDeltaUp);

  return (kRatingBase + delta).clamp(kMinRating, kMaxRating);
}

/// Calculates the Final (displayed) Rating.
/// [useEMA] = false -> Pickup Game Ranking (Day): Simple Arithmetic Average
///            de todas as partidas daquele dia (sem mudança).
/// [useEMA] = true  -> Nota Geral (perfil/ranking global): média só das
///            últimas [kFormWindowGames] partidas -- reflete a forma
///            recente do jogador, não o histórico de vida inteiro.
///
/// IMPORTANTE: [ratings] deve estar em ordem cronológica (mais antigo
/// primeiro, mais recente por último) -- é assim que sabemos quais são
/// "as últimas N partidas".
double calculateFinalRating({
  required List<double> ratings,
  bool useEMA = true,
}) {
  final int games = ratings.length;
  if (games == 0) return kRatingBase;

  if (!useEMA) {
    // Day ranking (Simple Average) -- comportamento inalterado.
    final double sum = ratings.fold(0.0, (acc, r) => acc + r);
    return (sum / games).clamp(kMinRating, kMaxRating);
  }

  // Nota geral: só as últimas kFormWindowGames partidas (forma recente).
  final recent = games > kFormWindowGames
      ? ratings.sublist(games - kFormWindowGames)
      : ratings;
  final double recentAvg =
      recent.fold(0.0, (acc, r) => acc + r) / recent.length;

  // Com poucos jogos no total, amortece em direção à base -- assim 1 ou 2
  // partidas isoladas não aparecem no perfil como nota extrema (9+ ou 3-).
  if (games < kFormAnchorGames) {
    final double weight = games / kFormAnchorGames; // 0..1
    final double anchored =
        (kRatingBase * (1 - weight)) + (recentAvg * weight);
    return anchored.clamp(kMinRating, kMaxRating);
  }

  return recentAvg.clamp(kMinRating, kMaxRating);
}

// --------------- Special goal detection ----------------------------

/// Resultado de [findSpecialGoals]: índices (na lista de eventos passada)
/// do gol da virada e do gol decisivo do fim de jogo, ou -1 se não houve.
class GoalContext {
  final int comebackGoalIndex;
  final int clutchGoalIndex;
  const GoalContext({
    required this.comebackGoalIndex,
    required this.clutchGoalIndex,
  });
}

int _parseTimeToSeconds(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return 0;
  final m = int.tryParse(parts[0]) ?? 0;
  final s = int.tryParse(parts[1]) ?? 0;
  return m * 60 + s;
}

/// Analisa a lista de eventos de uma partida (em ordem cronológica, no
/// mesmo formato usado em `matchEvents` do match_screen: cada evento com
/// 'type' ('goal'/'own_goal'), 'team' ('Vermelho'/'Branco'), 'playerId' e
/// 'time' no formato "MM:SS") e identifica dois gols especiais, usando só
/// dados que a partida já registra (sem pedir nada novo do usuário):
///
/// - **Gol da virada**: o gol que faz um time, que estava perdendo,
///   assumir a frente PELA PRIMEIRA VEZ na partida. Só conta gol "de
///   verdade" (não gol contra) -- quem fez contra não "vira o jogo".
/// - **Gol decisivo do fim de jogo**: precisa ser o ÚLTIMO gol da
///   partida, dentro da janela final (últimos [kClutchWindowFraction] do
///   tempo regulamentar), num jogo apertado até ali (diferença de até 1
///   gol antes dele), e que deixa quem marcou na frente ou empatado.
///
/// Cada bônus só pode acontecer uma vez por partida.
GoalContext findSpecialGoals(
  List<Map<String, dynamic>> events, {
  int regulationSeconds = kRegulationSeconds,
}) {
  int scoreRed = 0, scoreWhite = 0;
  bool redEverLed = false, whiteEverLed = false;
  int comebackIndex = -1;
  final List<int> goalIndices = [];

  for (int i = 0; i < events.length; i++) {
    final ev = events[i];
    final String? type = ev['type'] as String?;
    if (type != 'goal' && type != 'own_goal') continue;

    final bool redScored = (type == 'goal' && ev['team'] == 'Vermelho') ||
        (type == 'own_goal' && ev['team'] == 'Branco');
    final int beforeRed = scoreRed, beforeWhite = scoreWhite;

    if (redScored) {
      scoreRed++;
    } else {
      scoreWhite++;
    }

    if (type == 'goal') {
      goalIndices.add(i);
      if (comebackIndex == -1) {
        if (redScored &&
            beforeRed < beforeWhite &&
            scoreRed > scoreWhite &&
            !redEverLed) {
          comebackIndex = i;
        } else if (!redScored &&
            beforeWhite < beforeRed &&
            scoreWhite > scoreRed &&
            !whiteEverLed) {
          comebackIndex = i;
        }
      }
    }

    if (scoreRed > scoreWhite) redEverLed = true;
    if (scoreWhite > scoreRed) whiteEverLed = true;
  }

  int clutchIndex = -1;
  if (goalIndices.isNotEmpty) {
    final int lastIdx = goalIndices.last;
    final lastEv = events[lastIdx];
    final int seconds = _parseTimeToSeconds(lastEv['time'] as String? ?? '00:00');
    final double clutchStart = regulationSeconds * (1 - kClutchWindowFraction);

    // Placar final já reflete todos os gols; "antes" desse último gol é
    // só desfazer +1 no lado que marcou.
    final bool lastRedScored = lastEv['team'] == 'Vermelho';
    int rBefore = scoreRed, wBefore = scoreWhite;
    if (lastRedScored) {
      rBefore -= 1;
    } else {
      wBefore -= 1;
    }
    final int diffBefore = (rBefore - wBefore).abs();

    if (seconds >= clutchStart && diffBefore <= 1) {
      clutchIndex = lastIdx;
    }
  }

  return GoalContext(
    comebackGoalIndex: comebackIndex,
    clutchGoalIndex: clutchIndex,
  );
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

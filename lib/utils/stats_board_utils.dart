import '../models/match_model.dart';

/// Cálculos puros da tela de Estatísticas (docs/design/04-tela-estatisticas.md).

/// Gols, assistências e G+A de um mês.
class MonthBucket {
  final DateTime month;
  final int goals;
  final int assists;
  const MonthBucket(this.month, this.goals, this.assists);

  int get ga => goals + assists;
}

/// Média por jogador (entre quem atuou no mês) de cada série.
class MonthAverage {
  final DateTime month;
  final double goals;
  final double assists;
  const MonthAverage(this.month, this.goals, this.assists);

  double get ga => goals + assists;
}

/// Os [count] meses mais recentes, do mais antigo ao atual (dia 1, 00:00).
List<DateTime> lastMonths(DateTime now, {int count = 6}) => [
      for (var i = count - 1; i >= 0; i--) DateTime(now.year, now.month - i),
    ];

/// Evolução de um jogador nos 6 meses terminando em [now].
List<MonthBucket> monthlyEvolution(
  List<MatchModel> matches,
  String playerId, {
  required DateTime now,
  int count = 6,
}) {
  final months = lastMonths(now, count: count);
  final goals = List.filled(count, 0);
  final assists = List.filled(count, 0);
  for (final m in matches) {
    final idx = _monthIndex(months, m.timestamp);
    if (idx < 0) continue;
    for (final ev in m.events) {
      if (!ev.isGoal) continue;
      if (ev.playerId == playerId) goals[idx]++;
      if (ev.assistPlayerId == playerId) assists[idx]++;
    }
  }
  return [
    for (var i = 0; i < count; i++) MonthBucket(months[i], goals[i], assists[i]),
  ];
}

/// Média geral por mês: soma da série dividida pelo nº de jogadores que
/// atuaram (escalação) naquele mês. Mês sem jogos = 0.
List<MonthAverage> monthlyGroupAverages(
  List<MatchModel> matches, {
  required DateTime now,
  int count = 6,
}) {
  final months = lastMonths(now, count: count);
  final goals = List.filled(count, 0);
  final assists = List.filled(count, 0);
  final active = List.generate(count, (_) => <String>{});
  for (final m in matches) {
    final idx = _monthIndex(months, m.timestamp);
    if (idx < 0) continue;
    for (final l in m.lineups) {
      active[idx].add(l.playerId);
    }
    for (final ev in m.events) {
      if (!ev.isGoal) continue;
      if (ev.playerId.isNotEmpty) goals[idx]++;
      final a = ev.assistPlayerId;
      if (a != null && a.isNotEmpty) assists[idx]++;
    }
  }
  return [
    for (var i = 0; i < count; i++)
      active[i].isEmpty
          ? MonthAverage(months[i], 0, 0)
          : MonthAverage(
              months[i],
              goals[i] / active[i].length,
              assists[i] / active[i].length,
            ),
  ];
}

int _monthIndex(List<DateTime> months, DateTime t) {
  for (var i = 0; i < months.length; i++) {
    if (months[i].year == t.year && months[i].month == t.month) return i;
  }
  return -1;
}

/// Posições com empate na mesma posição visual (1, 1, 3). [values] já deve
/// estar ordenado do melhor para o pior.
List<int> rankWithTies(List<num> values) {
  final out = <int>[];
  for (var i = 0; i < values.length; i++) {
    out.add(i > 0 && values[i] == values[i - 1] ? out[i - 1] : i + 1);
  }
  return out;
}

/// Percentuais inteiros pelo método do maior resto: a soma fecha em 100
/// (ou 0 se não houver gols).
List<int> largestRemainderPercents(List<int> counts) {
  final total = counts.fold<int>(0, (a, b) => a + b);
  if (total == 0) return List.filled(counts.length, 0);
  final exact = [for (final c in counts) c * 100 / total];
  final result = [for (final e in exact) e.floor()];
  var missing = 100 - result.fold<int>(0, (a, b) => a + b);
  final order = List.generate(counts.length, (i) => i)
    ..sort((a, b) {
      final byRest = (exact[b] - result[b]).compareTo(exact[a] - result[a]);
      return byRest != 0 ? byRest : a.compareTo(b);
    });
  for (final i in order) {
    if (missing <= 0) break;
    result[i]++;
    missing--;
  }
  return result;
}

/// Id do jogador com mais G+A nos meses da janela (null se ninguém pontuou).
String? windowGaLeader(
  List<MatchModel> matches, {
  required DateTime now,
  int count = 6,
}) {
  final months = lastMonths(now, count: count);
  final totals = <String, int>{};
  for (final m in matches) {
    if (_monthIndex(months, m.timestamp) < 0) continue;
    for (final ev in m.events) {
      if (!ev.isGoal) continue;
      if (ev.playerId.isNotEmpty) {
        totals[ev.playerId] = (totals[ev.playerId] ?? 0) + 1;
      }
      final a = ev.assistPlayerId;
      if (a != null && a.isNotEmpty) totals[a] = (totals[a] ?? 0) + 1;
    }
  }
  String? best;
  var bestV = 0;
  totals.forEach((id, v) {
    if (v > bestV) {
      best = id;
      bestV = v;
    }
  });
  return best;
}

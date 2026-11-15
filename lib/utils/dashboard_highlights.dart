import '../models/session_model.dart';
import 'player_identity.dart';

/// Funções puras (sem Flutter, rede ou SharedPreferences) para a aba "Início".
///
/// Entrada: o histórico no formato de `getAllGroupMatches` (lista de mapas com
/// `sessionId`, `scoreRed`, `scoreWhite`, `events`, `players`) e a lista de
/// peladas ([SessionModel]).
///
/// Convenções (as mesmas da tela de estatísticas da temporada):
/// - G+A = gols + assistências; gol contra não conta;
/// - assistência só vale em evento de gol;
/// - só jogadores de linha: quem só jogou no gol não aparece (as partidas de
///   goleiro não contam como jogo);
/// - o mês vem da DATA DA PELADA (sessão), em horário local. Partida sem
///   pelada ou sem data é ignorada (nunca se usa `DateTime.now()`).

/// Mínimo de partidas no mês para entrar em destaque.
const int kHighlightMinMatches = 5;

class PlayerMonthStat {
  final String playerId;
  final String name;
  final String? icon;
  final int goals;
  final int assists;
  final int matches;
  final int wins;

  const PlayerMonthStat({
    required this.playerId,
    required this.name,
    required this.icon,
    required this.goals,
    required this.assists,
    required this.matches,
    required this.wins,
  });

  int get ga => goals + assists;
}

class LastSessionSummary {
  final String sessionId;
  final String name;
  final DateTime date;
  final int matches;
  final int totalGoals;

  /// Maior goleada (null se não houver partida com diferença de gols > 0).
  final int? bigWinRedScore;
  final int? bigWinWhiteScore;

  /// 'red' ou 'white' (time vencedor da maior goleada).
  final String? bigWinWinner;

  /// Artilheiro(s) da pelada (vários em caso de empate); vazio se ninguém fez gol.
  final List<PlayerMonthStat> topScorers;

  const LastSessionSummary({
    required this.sessionId,
    required this.name,
    required this.date,
    required this.matches,
    required this.totalGoals,
    required this.bigWinRedScore,
    required this.bigWinWhiteScore,
    required this.bigWinWinner,
    required this.topScorers,
  });
}

/// Chave 'aaaa-MM' de uma data, em horário local.
String monthKeyOf(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}';
}

/// Mês anterior a uma chave 'aaaa-MM'.
String previousMonthKey(String key) {
  final p = key.split('-');
  final y = int.parse(p[0]);
  final m = int.parse(p[1]);
  return m == 1
      ? '${(y - 1).toString().padLeft(4, '0')}-12'
      : '${y.toString().padLeft(4, '0')}-${(m - 1).toString().padLeft(2, '0')}';
}

class _Acc {
  final String id;
  String name;
  String? icon;
  int goals = 0;
  int assists = 0;
  int matches = 0;
  int wins = 0;
  _Acc(this.id, this.name, this.icon);

  PlayerMonthStat toStat() => PlayerMonthStat(
        playerId: id,
        name: name,
        icon: icon,
        goals: goals,
        assists: assists,
        matches: matches,
        wins: wins,
      );
}

int _score(dynamic v) => v is num ? v.toInt() : 0;

/// Soma por jogador de [history] filtrando as partidas de [sessionIds].
Map<String, PlayerMonthStat> _sumPlayers(
  List<dynamic> history,
  bool Function(String sessionId) accept,
) {
  final acc = <String, _Acc>{};

  _Acc get(String id, dynamic obj) {
    final a = acc.putIfAbsent(
        id,
        () => _Acc(id, (obj is Map ? obj['name'] : null)?.toString() ?? id,
            obj is Map ? obj['icon']?.toString() : null));
    if (obj is Map) {
      if ((a.icon == null || a.icon!.isEmpty) && obj['icon'] != null) {
        a.icon = obj['icon'].toString();
      }
    }
    return a;
  }

  for (final match in history) {
    if (match is! Map) continue;
    if (match['isExactCurrentSeason'] == false) continue;
    final sid = (match['sessionId'] ?? '').toString();
    if (sid.isEmpty || !accept(sid)) continue;
    final players = match['players'];
    if (players is! Map) continue;

    final scoreRed = _score(match['scoreRed']);
    final scoreWhite = _score(match['scoreWhite']);

    // Nomes/avatares de quem aparece só nos eventos (inclui goleiros).
    for (final key in const ['red', 'white']) {
      final list = players[key];
      if (list is! List) continue;
      for (final p in list) {
        final id = playerIdFromObject(p);
        if (id.isEmpty) continue;
        final a = get(id, p);
        a.matches++;
        final won = key == 'red' ? scoreRed > scoreWhite : scoreWhite > scoreRed;
        if (won) a.wins++;
      }
    }
    for (final key in const ['gk_red', 'gk_white']) {
      final gk = players[key];
      final id = playerIdFromObject(gk);
      if (id.isNotEmpty) get(id, gk); // só registra; jogo de goleiro não conta
    }

    final events = match['events'];
    if (events is! List) continue;
    for (final ev in events) {
      if (ev is! Map || ev['type'] != 'goal') continue; // gol contra ignorado
      final scorer = eventPlayerId(ev, 'player');
      if (scorer.isNotEmpty) get(scorer, null).goals++;
      final assister = eventPlayerId(ev, 'assist');
      if (assister.isNotEmpty) get(assister, null).assists++;
    }
  }

  return {for (final e in acc.entries) e.key: e.value.toStat()};
}

/// Soma do mês [monthKey] ('aaaa-MM'), só quem tem [kHighlightMinMatches]+ jogos
/// de linha.
List<PlayerMonthStat> _monthEligible(
  List<dynamic> history,
  List<SessionModel> sessions,
  String monthKey,
) {
  final inMonth = <String>{
    for (final s in sessions)
      if (s.id.isNotEmpty && monthKeyOf(s.sessionDate) == monthKey) s.id,
  };
  if (inMonth.isEmpty) return <PlayerMonthStat>[];
  return _sumPlayers(history, inMonth.contains)
      .values
      .where((p) => p.matches >= kHighlightMinMatches)
      .toList();
}

/// Quantas partidas (com pelada datada) existem no mês — para distinguir
/// "Poucos jogos neste mês" de mês sem dados.
int matchesInMonth(
  List<dynamic> history,
  List<SessionModel> sessions,
  String monthKey,
) {
  final inMonth = <String>{
    for (final s in sessions)
      if (s.id.isNotEmpty && monthKeyOf(s.sessionDate) == monthKey) s.id,
  };
  var n = 0;
  for (final m in history) {
    if (m is! Map || m['isExactCurrentSeason'] == false) continue;
    if (inMonth.contains((m['sessionId'] ?? '').toString())) n++;
  }
  return n;
}

/// Top 3 do mês: G+A, depois gols, depois vitórias, depois nome.
List<PlayerMonthStat> monthlyHighlight(
  List<dynamic> history,
  List<SessionModel> sessions,
  String monthKey,
) {
  final list = _monthEligible(history, sessions, monthKey)
    ..sort((a, b) {
      var c = b.ga.compareTo(a.ga);
      if (c != 0) return c;
      c = b.goals.compareTo(a.goals);
      if (c != 0) return c;
      c = b.wins.compareTo(a.wins);
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return list.take(3).toList();
}

/// Artilheiro do mês (gols; desempate vitórias, nome). Null se ninguém
/// elegível ou se ninguém fez gol.
PlayerMonthStat? topScorerOfMonth(
  List<dynamic> history,
  List<SessionModel> sessions,
  String monthKey,
) {
  final list = _monthEligible(history, sessions, monthKey)
      .where((p) => p.goals > 0)
      .toList()
    ..sort((a, b) {
      var c = b.goals.compareTo(a.goals);
      if (c != 0) return c;
      c = b.wins.compareTo(a.wins);
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return list.isEmpty ? null : list.first;
}

/// Garçom do mês (assistências; desempate vitórias, nome).
PlayerMonthStat? topAssisterOfMonth(
  List<dynamic> history,
  List<SessionModel> sessions,
  String monthKey,
) {
  final list = _monthEligible(history, sessions, monthKey)
      .where((p) => p.assists > 0)
      .toList()
    ..sort((a, b) {
      var c = b.assists.compareTo(a.assists);
      if (c != 0) return c;
      c = b.wins.compareTo(a.wins);
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return list.isEmpty ? null : list.first;
}

/// Pelada mais recente já finalizada (e com ao menos uma partida).
LastSessionSummary? lastSessionSummary(
  List<dynamic> history,
  List<SessionModel> sessions,
) {
  final withMatches = <String>{
    for (final m in history)
      if (m is Map && m['isExactCurrentSeason'] != false)
        (m['sessionId'] ?? '').toString(),
  }..remove('');

  final candidates = sessions
      .where((s) =>
          s.id.isNotEmpty &&
          s.status == SessionModel.statusFinished &&
          withMatches.contains(s.id))
      .toList()
    ..sort((a, b) {
      final c = b.sessionDate.compareTo(a.sessionDate);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  if (candidates.isEmpty) return null;
  final s = candidates.first;

  var count = 0;
  var totalGoals = 0;
  int? bestDiff;
  int? bestRed;
  int? bestWhite;
  for (final m in history) {
    if (m is! Map || m['isExactCurrentSeason'] == false) continue;
    if ((m['sessionId'] ?? '').toString() != s.id) continue;
    count++;
    final r = _score(m['scoreRed']);
    final w = _score(m['scoreWhite']);
    totalGoals += r + w;
    final diff = (r - w).abs();
    if (diff > 0 &&
        (bestDiff == null ||
            diff > bestDiff ||
            (diff == bestDiff && r + w > bestRed! + bestWhite!))) {
      bestDiff = diff;
      bestRed = r;
      bestWhite = w;
    }
  }

  final stats = _sumPlayers(history, (id) => id == s.id).values
      .where((p) => p.goals > 0)
      .toList();
  var max = 0;
  for (final p in stats) {
    if (p.goals > max) max = p.goals;
  }
  final scorers = stats.where((p) => p.goals == max && max > 0).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return LastSessionSummary(
    sessionId: s.id,
    name: s.title,
    date: s.sessionDate.toLocal(),
    matches: count,
    totalGoals: totalGoals,
    bigWinRedScore: bestRed,
    bigWinWhiteScore: bestWhite,
    bigWinWinner:
        bestDiff == null ? null : (bestRed! > bestWhite! ? 'red' : 'white'),
    topScorers: scorers,
  );
}

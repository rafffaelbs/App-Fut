import 'player_identity.dart';

/// Resumo de um jogador em UMA pelada (sessão): gols, assistências e V/E/D.
///
/// Função pura (sem Flutter, sem rede, sem SharedPreferences) para a aba
/// "Peladas" da carta do jogador. Segue as mesmas regras que a carta já usa
/// em `calculateGlobalStats` / `_calculateChartData`:
/// - só conta partida em que o jogador estava na escalação (linha ou goleiro);
/// - goleiro é tratado como qualquer jogador (conta jogo, V/E/D, gols e
///   assistências), exatamente como os totais da carta;
/// - gol contra não entra em gols nem em G+A;
/// - partida marcada com `isExactCurrentSeason == false` (pré-temporada no
///   caminho legado) fica de fora, igual aos totais da carta.
class PlayerSessionSummary {
  final String sessionId;

  /// Data da pelada (a mais antiga entre as suas partidas). Nula se o
  /// histórico não trouxer data.
  final DateTime? date;
  final int goals;
  final int assists;
  final int wins;
  final int draws;
  final int losses;

  const PlayerSessionSummary({
    required this.sessionId,
    required this.date,
    required this.goals,
    required this.assists,
    required this.wins,
    required this.draws,
    required this.losses,
  });

  int get ga => goals + assists;
  int get matches => wins + draws + losses;
}

class _Acc {
  final String sessionId;
  DateTime? date;
  int goals = 0;
  int assists = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;

  _Acc(this.sessionId);
}

bool _inTeam(dynamic field, dynamic gk, String id) {
  if (gk != null && playerIdFromObject(gk) == id) return true;
  if (field is! List) return false;
  return field.any((p) => playerIdFromObject(p) == id);
}

int _score(dynamic v) => v is num ? v.toInt() : 0;

String _dayKey(DateTime? d) => d == null
    ? 'sem-data'
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Agrupa por pelada o desempenho de [playerId] em [history] (mesmo formato
/// que `getAllGroupMatches` devolve) e devolve do mais recente ao mais antigo.
///
/// O histórico normalmente já chega filtrado pelo período da carta. [from] e
/// [to] (inclusivos; passe o fim do dia em [to]) permitem filtrar aqui também.
/// Partidas sem data ficam de fora quando [from] ou [to] são usados.
List<PlayerSessionSummary> summarizePlayerSessions(
  List<dynamic> history,
  String playerId, {
  DateTime? from,
  DateTime? to,
}) {
  if (playerId.isEmpty) return const [];
  final Map<String, _Acc> bySession = {};

  for (final match in history) {
    if (match is! Map) continue;
    if (match['isExactCurrentSeason'] == false) continue;
    final players = match['players'];
    if (players is! Map) continue;

    final bool inRed = _inTeam(players['red'], players['gk_red'], playerId);
    final bool inWhite =
        !inRed && _inTeam(players['white'], players['gk_white'], playerId);
    if (!inRed && !inWhite) continue;

    final dynamic rawDate = match['session_date'] ?? match['date'];
    final DateTime? date =
        rawDate == null ? null : DateTime.tryParse(rawDate.toString());
    if (from != null || to != null) {
      if (date == null) continue;
      if (from != null && date.isBefore(from)) continue;
      if (to != null && date.isAfter(to)) continue;
    }

    final String sessionId = (match['sessionId'] ?? '').toString();
    final String key = sessionId.isNotEmpty ? sessionId : 'dia:${_dayKey(date)}';
    final acc = bySession.putIfAbsent(key, () => _Acc(sessionId));
    if (date != null && (acc.date == null || date.isBefore(acc.date!))) {
      acc.date = date;
    }

    final int scoreRed = _score(match['scoreRed']);
    final int scoreWhite = _score(match['scoreWhite']);
    if (scoreRed == scoreWhite) {
      acc.draws++;
    } else if ((inRed && scoreRed > scoreWhite) ||
        (inWhite && scoreWhite > scoreRed)) {
      acc.wins++;
    } else {
      acc.losses++;
    }

    final events = match['events'];
    if (events is List) {
      for (final ev in events) {
        if (ev is! Map || ev['type'] != 'goal') continue;
        if (eventPlayerId(ev, 'player') == playerId) acc.goals++;
        if (eventPlayerId(ev, 'assist') == playerId) acc.assists++;
      }
    }
  }

  final entries = bySession.entries.toList()
    ..sort((a, b) {
      final da = a.value.date;
      final db = b.value.date;
      if (da == null && db == null) return a.key.compareTo(b.key);
      if (da == null) return 1; // sem data vai para o fim
      if (db == null) return -1;
      final c = db.compareTo(da); // mais recente primeiro
      return c != 0 ? c : a.key.compareTo(b.key);
    });

  return [
    for (final e in entries)
      PlayerSessionSummary(
        sessionId: e.value.sessionId,
        date: e.value.date,
        goals: e.value.goals,
        assists: e.value.assists,
        wins: e.value.wins,
        draws: e.value.draws,
        losses: e.value.losses,
      ),
  ];
}

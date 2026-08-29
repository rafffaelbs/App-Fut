import 'json_parsers.dart';

/// Estatísticas agregadas de um jogador, produzidas por
/// `calculateGlobalStats` e consumidas nas telas de ranking/perfil.
class PlayerStats {
  final String id;
  final String name;
  final int games;
  final int wins;
  final int draws;
  final int losses;
  final int goals;
  final int assists;
  final int yellow;
  final int red;
  final List<double> ratings;
  final double nota;

  const PlayerStats({
    required this.id,
    required this.name,
    this.games = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goals = 0,
    this.assists = 0,
    this.yellow = 0,
    this.red = 0,
    this.ratings = const [],
    this.nota = 0.0,
  });

  /// Compatível com o mapa retornado pelo `calculateGlobalStats` legado:
  /// `id`, `name`, `games`, `wins`, `draws`, `losses`, `goals`, `assists`,
  /// `yellow`, `red`, `ratings`, `nota`, `ga`.
  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      id: parseString(json['id']) ?? '',
      name: parseString(json['name']) ?? '',
      games: parseInt(json['games']),
      wins: parseInt(json['wins']),
      draws: parseInt(json['draws']),
      losses: parseInt(json['losses']),
      goals: parseInt(json['goals']),
      assists: parseInt(json['assists']),
      yellow: parseInt(json['yellow']),
      red: parseInt(json['red']),
      ratings: _parseRatings(json['ratings']),
      nota: parseDouble(json['nota']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'games': games,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'goals': goals,
      'assists': assists,
      'ga': ga,
      'yellow': yellow,
      'red': red,
      'ratings': ratings,
      'nota': nota,
    };
  }

  int get ga => goals + assists;

  static List<double> _parseRatings(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) => item is num ? item.toDouble() : 0.0)
          .toList();
    }
    return const [];
  }

  PlayerStats copyWith({
    String? id,
    String? name,
    int? games,
    int? wins,
    int? draws,
    int? losses,
    int? goals,
    int? assists,
    int? yellow,
    int? red,
    List<double>? ratings,
    double? nota,
  }) {
    return PlayerStats(
      id: id ?? this.id,
      name: name ?? this.name,
      games: games ?? this.games,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      goals: goals ?? this.goals,
      assists: assists ?? this.assists,
      yellow: yellow ?? this.yellow,
      red: red ?? this.red,
      ratings: ratings ?? this.ratings,
      nota: nota ?? this.nota,
    );
  }
}
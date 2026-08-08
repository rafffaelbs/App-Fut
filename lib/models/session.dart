import 'json_parsers.dart';

class Session {
  static const String statusEmAndamento = 'Em Andamento';

  final String id;
  final String title;
  final String date;
  final String? timestamp;
  final String status;
  final int jogadores;
  final int duration;
  final int winLimit;
  final String streakAction;
  final bool draftMode;

  const Session({
    required this.id,
    required this.title,
    required this.date,
    required this.timestamp,
    required this.status,
    required this.jogadores,
    required this.duration,
    required this.winLimit,
    required this.streakAction,
    required this.draftMode,
  });

  /// Cria uma [Session] a partir do JSON persistido em `sessions_{groupId}`.
  ///
  /// Compatível com as chaves legadas:
  /// `id`, `title`, `date`, `timestamp`, `status`, `jogadores`, `duration`,
  /// `win_limit`, `streak_action`, `draft_mode`.
  factory Session.fromJson(Map<String, dynamic> json) {
    final String? rawId = parseString(json['id']);
    final String? rawTitle = parseString(json['title']);
    return Session(
      id: rawId != null && rawId.trim().isNotEmpty ? rawId : _fallbackId(rawTitle),
      title: rawTitle ?? '',
      date: parseString(json['date']) ?? '',
      timestamp: parseString(json['timestamp']),
      status: parseString(json['status']) ?? statusEmAndamento,
      jogadores: parseInt(json['jogadores'], fallback: 5),
      duration: parseInt(json['duration'], fallback: 8),
      winLimit: parseInt(json['win_limit'], fallback: 3),
      streakAction: parseString(json['streak_action']) ?? 'split',
      draftMode: parseBool(json['draft_mode']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'date': date,
      'timestamp': timestamp,
      'status': status,
      'jogadores': jogadores,
      'duration': duration,
      'win_limit': winLimit,
      'streak_action': streakAction,
      'draft_mode': draftMode,
    };
  }

  bool get isLive => status == statusEmAndamento;

  bool get hasInfiniteWinLimit => winLimit == 0;

  DateTime? get dateTime {
    final String? raw = timestamp;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Session copyWith({
    String? id,
    String? title,
    String? date,
    String? timestamp,
    String? status,
    int? jogadores,
    int? duration,
    int? winLimit,
    String? streakAction,
    bool? draftMode,
  }) {
    return Session(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      jogadores: jogadores ?? this.jogadores,
      duration: duration ?? this.duration,
      winLimit: winLimit ?? this.winLimit,
      streakAction: streakAction ?? this.streakAction,
      draftMode: draftMode ?? this.draftMode,
    );
  }

  static String _fallbackId(String? rawTitle) {
    return 'sem_id_${(rawTitle ?? '').hashCode}';
  }
}
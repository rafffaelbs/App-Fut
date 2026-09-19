class SessionModel {
  static const String statusInProgress = 'em_andamento';
  static const String statusFinished = 'finalizada';

  final String id;
  final String groupId;
  final String? seasonId;
  final String title;
  final DateTime sessionDate;
  final String status;
  final int? durationMinutes;
  final int? winLimit;

  // Transient/Legacy properties needed by UI
  final int playerCount;
  final String streakAction;
  final bool draftMode;

  const SessionModel({
    required this.id,
    required this.groupId,
    this.seasonId,
    required this.title,
    required this.sessionDate,
    this.status = statusFinished,
    this.durationMinutes,
    this.winLimit,
    this.playerCount = 5,
    this.streakAction = 'split',
    this.draftMode = false,
  });

  /// Legacy alias -- lots of existing UI code reads `.timestamp`/`.dateTime`.
  DateTime get timestamp => sessionDate;

  bool get isLive => status == statusInProgress || status.toLowerCase() == 'em andamento';

  bool get hasInfiniteWinLimit => winLimit == 0;

  DateTime? get dateTime => sessionDate;

  String get date {
    return '${sessionDate.day.toString().padLeft(2, '0')}/${sessionDate.month.toString().padLeft(2, '0')}/${sessionDate.year}';
  }

  // Getters for compatibility with legacy UI that expects duration
  int? get duration => durationMinutes;

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    // 'session_date' is the real column (schema); 'timestamp' is kept as a
    // fallback for any old local/cached maps still floating around.
    final rawDate = map['session_date'] ?? map['timestamp'];
    return SessionModel(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      seasonId: map['season_id']?.toString(),
      title: map['title']?.toString() ?? '',
      sessionDate: rawDate != null
          ? DateTime.tryParse(rawDate.toString()) ?? DateTime.now()
          : DateTime.now(),
      status: map['status']?.toString() ?? statusFinished,
      durationMinutes: map['match_duration_minutes'] != null
          ? int.tryParse(map['match_duration_minutes'].toString())
          : (map['duration_minutes'] != null
              ? int.tryParse(map['duration_minutes'].toString())
              : null),
      winLimit: map['win_limit'] != null
          ? int.tryParse(map['win_limit'].toString())
          : null,
      playerCount: map['player_count'] != null
          ? int.tryParse(map['player_count'].toString()) ?? 5
          : (map['jogadores'] != null ? int.tryParse(map['jogadores'].toString()) ?? 5 : 5),
      streakAction: map['streak_action']?.toString() ?? 'split',
      draftMode: map['draft_mode'] == true || map['draft_mode'] == 'true',
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final data = <String, dynamic>{
      'group_id': groupId,
      'season_id': seasonId,
      'title': title,
      // DATE column -- send just the date part, not a full timestamp.
      'session_date': sessionDate.toIso8601String().split('T').first,
      'status': status,
      'match_duration_minutes': durationMinutes,
      'win_limit': winLimit,
      'player_count': playerCount,
      'streak_action': streakAction,
      'draft_mode': draftMode,
    };
    if (includeId && id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }

  SessionModel copyWith({
    String? id,
    String? groupId,
    String? seasonId,
    String? title,
    DateTime? sessionDate,
    String? status,
    int? durationMinutes,
    int? winLimit,
    int? playerCount,
    String? streakAction,
    bool? draftMode,
  }) {
    return SessionModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      seasonId: seasonId ?? this.seasonId,
      title: title ?? this.title,
      sessionDate: sessionDate ?? this.sessionDate,
      status: status ?? this.status,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      winLimit: winLimit ?? this.winLimit,
      playerCount: playerCount ?? this.playerCount,
      streakAction: streakAction ?? this.streakAction,
      draftMode: draftMode ?? this.draftMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SessionModel(id: $id, title: $title, status: $status)';
}

class SessionModel {
  static const String statusEmAndamento = 'em_andamento';
  static const String statusFinalizada = 'finalizada';

  final String id;
  final String? seasonId;
  final String title;
  final DateTime timestamp;
  final String status;
  final int? durationMinutes;
  final int? winLimit;

  // Transient/Legacy properties needed by UI
  final int jogadores;
  final String streakAction;
  final bool draftMode;

  const SessionModel({
    required this.id,
    this.seasonId,
    required this.title,
    required this.timestamp,
    this.status = statusFinalizada,
    this.durationMinutes,
    this.winLimit,
    this.jogadores = 5,
    this.streakAction = 'split',
    this.draftMode = false,
  });

  bool get isLive => status == statusEmAndamento || status.toLowerCase() == 'em andamento';
  
  bool get hasInfiniteWinLimit => winLimit == 0;
  
  DateTime? get dateTime => timestamp;
  
  String get date {
    return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
  }

  // Getters for compatibility with legacy UI that expects duration
  int? get duration => durationMinutes;

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id']?.toString() ?? '',
      seasonId: map['season_id']?.toString(),
      title: map['title']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: map['status']?.toString() ?? statusFinalizada,
      durationMinutes: map['duration_minutes'] != null
          ? int.tryParse(map['duration_minutes'].toString())
          : null,
      winLimit: map['win_limit'] != null
          ? int.tryParse(map['win_limit'].toString())
          : null,
      jogadores: map['jogadores'] != null ? int.tryParse(map['jogadores'].toString()) ?? 5 : 5,
      streakAction: map['streak_action']?.toString() ?? 'split',
      draftMode: map['draft_mode'] == true || map['draft_mode'] == 'true',
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final data = <String, dynamic>{
      'season_id': seasonId,
      'title': title,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'duration_minutes': durationMinutes,
      'win_limit': winLimit,
    };
    if (includeId && id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }

  SessionModel copyWith({
    String? id,
    String? seasonId,
    String? title,
    DateTime? timestamp,
    String? status,
    int? durationMinutes,
    int? winLimit,
    int? jogadores,
    String? streakAction,
    bool? draftMode,
  }) {
    return SessionModel(
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      title: title ?? this.title,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      winLimit: winLimit ?? this.winLimit,
      jogadores: jogadores ?? this.jogadores,
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

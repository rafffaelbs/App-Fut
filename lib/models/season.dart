import 'json_parsers.dart';

class Season {
  final String id;
  final String name;
  final String? startDate;
  final String? endDate;
  final bool isPreSeason;
  final String? parentSeasonId;

  const Season({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    this.isPreSeason = false,
    this.parentSeasonId,
  });

  /// Cria uma [Season] a partir do JSON persistido em `seasons_{groupId}`.
  ///
  /// Compatível com as chaves legadas:
  /// `id`, `name`, `startDate`, `endDate`, `isPreSeason`, `parentSeasonId`.
  factory Season.fromJson(Map<String, dynamic> json) {
    final String? rawId = parseString(json['id']);
    final String? rawName = parseString(json['name']);
    return Season(
      id: rawId != null && rawId.trim().isNotEmpty ? rawId : _fallbackId(rawName),
      name: rawName ?? '',
      startDate: parseString(json['startDate']),
      endDate: parseString(json['endDate']),
      isPreSeason: parseBool(json['isPreSeason']),
      parentSeasonId: parseString(json['parentSeasonId']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      'isPreSeason': isPreSeason,
      if (parentSeasonId != null) 'parentSeasonId': parentSeasonId,
    };
  }

  DateTime? get start {
    final String? raw = startDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  DateTime? get end {
    final String? raw = endDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Id efetivo usado para agrupar estatísticas: pre-season aponta para a
  /// temporada principal (pai), assim como `stats_calculator.dart` já fazia.
  String get effectiveId {
    if (isPreSeason && parentSeasonId != null &&
        parentSeasonId!.trim().isNotEmpty) {
      return parentSeasonId!;
    }
    return id;
  }

  bool get hasDateRange => start != null && end != null;

  /// Inclui a pre-season considerando o dia seguinte ao `endDate`
  /// (lógica legada de `stats_calculator.dart`).
  bool covers(DateTime dateTime) {
    final DateTime? start = this.start;
    final DateTime? end = this.end;
    if (start == null || end == null) return false;
    final DateTime inclusiveEnd = end.add(const Duration(days: 1));
    return dateTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
        dateTime.isBefore(inclusiveEnd);
  }

  static String _fallbackId(String? rawName) {
    return 'sem_id_${(rawName ?? '').hashCode}';
  }
}
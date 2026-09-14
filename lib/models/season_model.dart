/// Model for the `seasons` table in Supabase PostgreSQL.
class SeasonModel {
  final String id;
  final String groupId;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  const SeasonModel({
    required this.id,
    required this.groupId,
    required this.name,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  /// Getters for backward compatibility.
  String get nome => name;
  String get grupoId => groupId;
  DateTime? get dataInicio => startDate;
  DateTime? get dataFim => endDate;
  bool get isAtual => isActive;

  factory SeasonModel.fromMap(Map<String, dynamic> map) {
    return SeasonModel(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'].toString())
          : null,
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'].toString())
          : null,
      isActive: map['is_active'] == true,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final data = <String, dynamic>{
      'group_id': groupId,
      'name': name,
      'start_date': startDate != null
          ? "${startDate!.year.toString().padLeft(4, '0')}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}"
          : null,
      'end_date': endDate != null
          ? "${endDate!.year.toString().padLeft(4, '0')}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}"
          : null,
      'is_active': isActive,
    };
    if (includeId && id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }

  SeasonModel copyWith({
    String? id,
    String? groupId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) {
    return SeasonModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeasonModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SeasonModel(id: $id, name: $name, isActive: $isActive)';
}

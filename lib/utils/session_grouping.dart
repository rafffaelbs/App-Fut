import '../models/session_model.dart';

const List<String> _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/// Peladas de um mês, para o cabeçalho fixo da Home ("Outubro 2026").
class SessionMonthGroup {
  final int year;
  final int month;
  final List<SessionModel> sessions;

  const SessionMonthGroup(this.year, this.month, this.sessions);

  String get title => '${_monthNames[month - 1]} $year';
}

/// Agrupa por mês preservando a ordem recebida (mais recente primeiro).
List<SessionMonthGroup> groupSessionsByMonth(List<SessionModel> sessions) {
  final groups = <SessionMonthGroup>[];
  for (final s in sessions) {
    final d = s.sessionDate;
    if (groups.isEmpty || groups.last.year != d.year || groups.last.month != d.month) {
      groups.add(SessionMonthGroup(d.year, d.month, []));
    }
    groups.last.sessions.add(s);
  }
  return groups;
}

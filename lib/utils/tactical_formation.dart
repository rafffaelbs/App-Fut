import 'package:flutter/foundation.dart';

/// Ponto de um jogador na metade do campo.
///
/// [x] vai de -1 (esquerda) a 1 (direita).
/// [depth] vai de 0 (perto do próprio gol) a 1 (perto do meio-campo / ataque).
@immutable
class FormationSlot {
  final double x;
  final double depth;
  const FormationSlot(this.x, this.depth);
}

/// Formações de linha (sem goleiro) para pelada.
///
/// - 1 / 2 / 3: linha
/// - 4: losango (1-2-1)
/// - 5: 2-3
/// - 6: 2-3-1
/// - 7: 2-3-2
/// - 8+: linhas de no máximo 3
List<FormationSlot> tacticalFormation(int teamSize) {
  final n = teamSize < 0 ? 0 : teamSize;
  switch (n) {
    case 0:
      return const [];
    case 1:
      return const [FormationSlot(0, 0.50)];
    case 2:
      return const [
        FormationSlot(-0.46, 0.50),
        FormationSlot(0.46, 0.50),
      ];
    case 3:
      return const [
        FormationSlot(-0.64, 0.50),
        FormationSlot(0.00, 0.50),
        FormationSlot(0.64, 0.50),
      ];
    case 4: // losango
      return const [
        FormationSlot(0.00, 0.14),
        FormationSlot(-0.64, 0.50),
        FormationSlot(0.64, 0.50),
        FormationSlot(0.00, 0.88),
      ];
    case 5: // 2-3
      return const [
        FormationSlot(-0.38, 0.22),
        FormationSlot(0.38, 0.22),
        FormationSlot(-0.64, 0.78),
        FormationSlot(0.00, 0.78),
        FormationSlot(0.64, 0.78),
      ];
    case 6: // 2-3-1
      return const [
        FormationSlot(-0.38, 0.14),
        FormationSlot(0.38, 0.14),
        FormationSlot(-0.64, 0.50),
        FormationSlot(0.00, 0.50),
        FormationSlot(0.64, 0.50),
        FormationSlot(0.00, 0.88),
      ];
    case 7: // 2-3-2
      return const [
        FormationSlot(-0.38, 0.12),
        FormationSlot(0.38, 0.12),
        FormationSlot(-0.68, 0.48),
        FormationSlot(0.00, 0.48),
        FormationSlot(0.68, 0.48),
        FormationSlot(-0.38, 0.86),
        FormationSlot(0.38, 0.86),
      ];
    default:
      return _rowsOfThree(n);
  }
}

String formationLabel(int teamSize) {
  switch (teamSize) {
    case 1:
    case 2:
    case 3:
      return 'Linha';
    case 4:
      return 'Losango';
    case 5:
      return '2-3';
    case 6:
      return '2-3-1';
    case 7:
      return '2-3-2';
    default:
      return '$teamSize jogadores';
  }
}

List<FormationSlot> _rowsOfThree(int n) {
  final rows = <List<int>>[];
  var remaining = n;
  while (remaining > 0) {
    final take = remaining > 3 ? 3 : remaining;
    rows.add(List<int>.generate(take, (i) => i));
    remaining -= take;
  }
  final slots = <FormationSlot>[];
  for (var r = 0; r < rows.length; r++) {
    final depth = rows.length == 1 ? 0.50 : r / (rows.length - 1);
    final cols = rows[r].length;
    for (var c = 0; c < cols; c++) {
      final x = cols == 1 ? 0.0 : -0.64 + (1.28 * c / (cols - 1));
      slots.add(FormationSlot(x, depth));
    }
  }
  return slots;
}

/// Fileiras de jogadores de linha, do goleiro para o meio-campo
/// (docs/design/03-tela-partida.md §4.5). O goleiro não entra na lista.
///
/// 4 → 2-2 (5×5) · 5 → 2-2-1 (6×6) · 6 → 3-2-1 (7×7) · 10 → 4-4-2 (11×11).
List<int> formationRows(int lineCount) {
  final n = lineCount < 0 ? 0 : lineCount;
  switch (n) {
    case 0:
      return const [];
    case 1:
      return const [1];
    case 2:
      return const [2];
    case 3:
      return const [1, 2];
    case 4:
      return const [2, 2];
    case 5:
      return const [2, 2, 1];
    case 6:
      return const [3, 2, 1];
    case 7:
      return const [3, 3, 1];
    case 8:
      return const [3, 3, 2];
    case 9:
      return const [4, 3, 2];
    case 10:
      return const [4, 4, 2];
    default:
      final rows = <int>[];
      var left = n;
      while (left > 0) {
        final take = left > 4 ? 4 : left;
        rows.add(take);
        left -= take;
      }
      return rows;
  }
}

/// Formações alternativas de jogadores de linha (sem goleiro), da primeira
/// (padrão, igual a [formationRows]) às demais. Cada uma soma [lineCount].
List<List<int>> formationPresets(int lineCount) {
  final base = formationRows(lineCount);
  final extra = switch (lineCount) {
    3 => const [
        [2, 1],
        [3],
      ],
    4 => const [
        [1, 2, 1],
        [1, 1, 2],
        [3, 1],
      ],
    5 => const [
        [2, 1, 2],
        [1, 2, 2],
        [1, 1, 2, 1],
      ],
    6 => const [
        [2, 3, 1],
        [2, 2, 2],
        [3, 1, 2],
      ],
    7 => const [
        [3, 2, 2],
        [2, 3, 2],
        [3, 2, 1, 1],
      ],
    _ => const <List<int>>[],
  };
  return [base, ...extra];
}

String formationRowsLabel(List<int> rows) => rows.join('-');

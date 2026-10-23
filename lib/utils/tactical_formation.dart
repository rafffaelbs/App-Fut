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

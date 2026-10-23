import 'dart:ui';

import 'package:app_do_fut/utils/pitch_layout.dart';
import 'package:app_do_fut/utils/tactical_formation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formationRows soma o número de jogadores de linha', () {
    for (var n = 0; n <= 14; n++) {
      expect(formationRows(n).fold<int>(0, (a, b) => a + b), n);
    }
  });

  // 5×5, 6×6, 7×7 e 11×11 (jogadores de linha + goleiro).
  for (final n in [4, 5, 6, 10]) {
    for (final width in [360.0, 412.0]) {
      for (final avail in [440.0, 640.0]) {
        for (final focus in PitchFocus.values) {
          test('sem sobreposição: n=$n w=$width h=$avail $focus', () {
            final h = avail > PitchLayout.minHeight(n)
                ? avail
                : PitchLayout.minHeight(n);
            final field = Size(width, h);
            final r = PitchLayout.compute(lineCount: n, field: field, focus: focus);
            final teams = focus == PitchFocus.both ? 2 : 1;
            expect(r.slots, hasLength((n + 1) * teams));
            expect(PitchLayout.hasOverlap(r.slots), isFalse);
            final bounds = Offset.zero & field;
            for (final s in r.slots) {
              expect(bounds.contains(s.itemRect.topLeft), isTrue);
              expect(bounds.contains(s.itemRect.bottomRight), isTrue);
              if (focus == PitchFocus.both) {
                final mid = Rect.fromLTRB(0, h * 0.44, width, h * 0.56);
                expect(s.itemRect.overlaps(mid), isFalse);
              }
            }
          });
        }
      }
    }
  }

  test("11×11 usa chips S e 5×5 usa M no formato padrão", () {
    final f11 = Size(360, PitchLayout.minHeight(10));
    expect(PitchLayout.compute(lineCount: 10, field: f11).density,
        PitchLayout.preferredDensity(10));
    final f5 = Size(360, PitchLayout.minHeight(4));
    expect(PitchLayout.compute(lineCount: 4, field: f5).density,
        PitchLayout.preferredDensity(4));
  });

  test('presets de formação somam o total e não se sobrepõem', () {
    for (final n in [3, 4, 5, 6, 7]) {
      for (final rows in formationPresets(n)) {
        expect(rows.fold<int>(0, (a, b) => a + b), n);
        final h = PitchLayout.minHeight(n, formation: rows);
        final r = PitchLayout.compute(
            lineCount: n, field: Size(380, h), formation: rows);
        expect(PitchLayout.hasOverlap(r.slots), isFalse, reason: '$n $rows');
      }
    }
  });
}

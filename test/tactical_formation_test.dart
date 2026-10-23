import 'package:app_do_fut/utils/tactical_formation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada tamanho de time gera a quantidade certa de posições', () {
    for (var n = 0; n <= 10; n++) {
      expect(tacticalFormation(n), hasLength(n));
    }
  });

  test('4x4 é um losango 1-2-1', () {
    final slots = tacticalFormation(4);
    expect(slots[0].x, 0);
    expect(slots[0].depth, lessThan(slots[1].depth));
    expect(slots[1].x, lessThan(0));
    expect(slots[2].x, greaterThan(0));
    expect(slots[3].x, 0);
    expect(slots[3].depth, greaterThan(slots[1].depth));
  });

  test('5x5 é 2-3', () {
    final slots = tacticalFormation(5);
    expect(slots.take(2).every((s) => s.depth < 0.5), isTrue);
    expect(slots.skip(2).every((s) => s.depth > 0.5), isTrue);
  });

  test('6x6 é 2-3-1 e 7x7 é 2-3-2', () {
    expect(tacticalFormation(6)[5].x, 0);
    expect(tacticalFormation(6)[5].depth, greaterThan(0.7));
    expect(tacticalFormation(7)[5].x, lessThan(0));
    expect(tacticalFormation(7)[6].x, greaterThan(0));
  });

  test('1x1, 2x2 e 3x3 ficam em linha', () {
    expect(tacticalFormation(1).single.x, 0);
    expect(tacticalFormation(2).map((s) => s.depth).toSet(), hasLength(1));
    expect(tacticalFormation(3).map((s) => s.depth).toSet(), hasLength(1));
  });
}

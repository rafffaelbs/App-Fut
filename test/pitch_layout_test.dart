import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/utils/pitch_layout.dart';

void main() {
  group('PitchLayout Tests', () {
    test('computes vertical layout without overlap', () {
      for (final teamSize in [4, 5, 6, 7]) {
        final height = PitchLayout.minHeight(teamSize);
        final size = Size(380, height);
        final result = PitchLayout.compute(
          lineCount: teamSize,
          field: size,
          isHorizontal: false,
        );

        expect(result.slots.isNotEmpty, isTrue);
        // Cada time tem lineCount + 1 (goleiro)
        expect(result.slots.length, equals((teamSize + 1) * 2));
        expect(PitchLayout.hasOverlap(result.slots), isFalse,
            reason: 'Vertical teamSize=$teamSize should not have overlap');
      }
    });

    test('computes horizontal layout without overlap by default', () {
      final size = const Size(380, 260);
      for (final teamSize in [4, 5, 6, 7]) {
        final result = PitchLayout.compute(
          lineCount: teamSize,
          field: size,
          isHorizontal: true,
        );

        expect(result.slots.isNotEmpty, isTrue);
        expect(result.slots.length, equals((teamSize + 1) * 2));
        expect(PitchLayout.hasOverlap(result.slots), isFalse,
            reason: 'Horizontal teamSize=$teamSize should not have overlap');

        // Red GK está no lado esquerdo (x < 0.3) e White GK está no lado direito (x > 0.7)
        final redGk = result.slots.firstWhere((s) => s.isRed && s.isGk);
        final whiteGk = result.slots.firstWhere((s) => !s.isRed && s.isGk);

        expect(redGk.rect.center.dx, lessThan(size.width * 0.35));
        expect(whiteGk.rect.center.dx, greaterThan(size.width * 0.65));
      }
    });

    test('horizontal layout with chips works for larger formations', () {
      final size = const Size(380, 260);
      final result = PitchLayout.compute(
        lineCount: 10, // 11x11
        field: size,
        chips: true,
        isHorizontal: true,
      );

      expect(result.slots.length, equals(22));
      expect(PitchLayout.hasOverlap(result.slots), isFalse);
    });

    test('focus on red team in horizontal keeps red slots in full width', () {
      final size = const Size(380, 260);
      final result = PitchLayout.compute(
        lineCount: 5,
        field: size,
        focus: PitchFocus.red,
        isHorizontal: true,
      );

      // Apenas time vermelho deve estar presente
      expect(result.slots.every((s) => s.isRed), isTrue);
      expect(result.slots.length, equals(6));
      expect(PitchLayout.hasOverlap(result.slots), isFalse);
    });
  });
}

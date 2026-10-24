import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/utils/constants.dart';
import 'package:app_do_fut/models/player_model.dart';

void main() {
  group('Goal Audio Loop Helpers', () {
    test('parseGoalSounds returns a growable mutable list even on null or empty', () {
      final listNull = parseGoalSounds(null);
      expect(listNull, isEmpty);
      // Ensure it is mutable and can have items added without throwing
      expect(() => listNull.add('audio1.mp3'), returnsNormally);
      expect(listNull, equals(['audio1.mp3']));

      final listEmpty = parseGoalSounds('');
      expect(listEmpty, isEmpty);
      expect(() => listEmpty.add('audio2.mp3'), returnsNormally);
      expect(listEmpty, equals(['audio2.mp3']));
    });

    test('parseGoalSounds parses multiple items correctly', () {
      expect(
        parseGoalSounds('siuuuuu.mp3, ratinho.mp3,  zapzap.mp3 '),
        equals(['siuuuuu.mp3', 'ratinho.mp3', 'zapzap.mp3']),
      );
    });

    test('formatGoalSounds formats list to comma-separated string or null', () {
      expect(formatGoalSounds([]), isNull);
      expect(formatGoalSounds([' ']), isNull);
      expect(formatGoalSounds(['siuuuuu.mp3']), equals('siuuuuu.mp3'));
      expect(
        formatGoalSounds(['siuuuuu.mp3', 'ratinho.mp3', 'zapzap.mp3']),
        equals('siuuuuu.mp3,ratinho.mp3,zapzap.mp3'),
      );
    });

    test('getGoalAudioLabel formats single sound and loop labels appropriately', () {
      expect(getGoalAudioLabel(null), equals('Padrão'));
      expect(getGoalAudioLabel(''), equals('Padrão'));
      expect(getGoalAudioLabel('siuuuuu.mp3'), equals('Siuuuuu'));
      expect(
        getGoalAudioLabel('siuuuuu.mp3,ratinho.mp3'),
        equals('Loop (2): Siuuuuu ➔ Ratinho Gol'),
      );
    });

    test('PlayerModel parses goalSoundUrls property correctly', () {
      final player = PlayerModel(
        id: 'p1',
        name: 'Craque',
        goalSoundUrl: 'siuuuuu.mp3,ratinho.mp3',
      );

      expect(player.goalSoundUrls, equals(['siuuuuu.mp3', 'ratinho.mp3']));
    });
  });
}

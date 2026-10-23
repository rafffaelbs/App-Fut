import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/models/cosmetic_effect.dart';
import 'package:app_do_fut/models/player_model.dart';

void main() {
  group('PlayerModel cosméticos', () {
    test('lê colunas novas', () {
      final p = PlayerModel.fromMap({
        'id': '1',
        'name': 'A',
        'golden_ball': true,
        'name_effect': 'fire',
        'monthly_star_count': 3,
      });
      expect(p.goldenBall, isTrue);
      expect(p.cosmeticEffect, CosmeticEffect.fire);
      expect(p.monthlyStarCount, 3);
    });

    test('fallback legado antes da migração', () {
      final p = PlayerModel.fromMap({
        'id': '1',
        'name': 'A',
        'name_effect': 'gold',
        'monthly_highlight': true,
        'advanced_stats': {
          'bola_de_ouro': true,
          'name_effect_extra': 'diamond',
          'craque_mes_count': 4,
        },
      });
      expect(p.goldenBall, isTrue);
      expect(p.cosmeticEffect, CosmeticEffect.diamond);
      expect(p.monthlyStarCount, 4);
    });

    test('monthly_highlight sem contador vale 1 estrela; sem destaque vale 0', () {
      expect(
          PlayerModel.fromMap({'id': '1', 'name': 'A', 'monthly_highlight': true})
              .monthlyStarCount,
          1);
      expect(PlayerModel.fromMap({'id': '1', 'name': 'A'}).monthlyStarCount, 0);
    });

    test('valor inválido vira none e estrelas ficam em 0..6', () {
      final p = PlayerModel.fromMap(
          {'id': '1', 'name': 'A', 'name_effect': 'xyz', 'monthly_star_count': 9});
      expect(p.cosmeticEffect, CosmeticEffect.none);
      expect(p.monthlyStarCount, 6);
    });

    test('toMap não inclui colunas novas; cosmeticsToMap sim', () {
      final p = PlayerModel(id: '1', name: 'A', goldenBall: true, monthlyStarCount: 2);
      expect(p.toMap().containsKey('golden_ball'), isFalse);
      expect(p.cosmeticsToMap()['golden_ball'], isTrue);
      expect(p.cosmeticsToMap()['monthly_star_count'], 2);
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:app_do_fut/utils/overall_calculator.dart';
import 'package:app_do_fut/utils/roster_utils.dart';
import 'package:app_do_fut/utils/team_balancer.dart';

BalancePlayer _p(String id, double r) => BalancePlayer(id, r);

Map<String, dynamic> _m(String id, {bool gaveUp = false}) => {
      'id': id,
      'name': id,
      if (gaveUp) 'desistiu': true,
    };

void main() {
  group('TeamBalancer', () {
    test('acha a divisão perfeita quando ela existe', () {
      final pool = [_p('a', 90), _p('b', 80), _p('c', 70), _p('d', 60)];
      final best = TeamBalancer.best(pool, random: Random(1));
      expect(best.diff, 0);
      expect(best.a.length, 2);
      expect(best.b.length, 2);
    });

    test('sugestões têm tamanhos certos, sem repetição e sem jogador duplicado',
        () {
      final pool = [
        for (int i = 0; i < 10; i++) _p('j$i', 60.0 + i * 3),
      ];
      final sug = TeamBalancer.suggest(pool,
          count: 3, tolerance: 3, random: Random(7));
      expect(sug.length, 3);
      expect(sug.map((s) => s.key).toSet().length, 3);
      for (final s in sug) {
        expect(s.a.length, 5);
        expect(s.b.length, 5);
        final ids = [...s.a, ...s.b].map((p) => p.id).toSet();
        expect(ids.length, 10);
      }
    });

    test('nunca devolve uma divisão excluída (último sorteio)', () {
      final pool = [
        for (int i = 0; i < 6; i++) _p('j$i', 70.0 + i),
      ];
      final first = TeamBalancer.best(pool, random: Random(2));
      for (int seed = 0; seed < 20; seed++) {
        final sug = TeamBalancer.suggest(pool,
            count: 3,
            tolerance: 100,
            excludeKeys: {first.key},
            random: Random(seed));
        expect(sug.every((s) => s.key != first.key), isTrue);
      }
    });

    test('espalha elites quando dá', () {
      // 4 elites + 6 comuns: o ideal é 2 elites de cada lado.
      final pool = [
        _p('e1', 92), _p('e2', 90), _p('e3', 88), _p('e4', 86), //
        _p('c1', 70), _p('c2', 69), _p('c3', 68), _p('c4', 67),
        _p('c5', 66), _p('c6', 65),
      ];
      final best = TeamBalancer.best(pool, random: Random(3));
      expect(best.eliteGap, 0);
    });

    test('grupo grande (>20) também devolve times de tamanho certo', () {
      final pool = [
        for (int i = 0; i < 22; i++) _p('j$i', 55.0 + (i * 7) % 40),
      ];
      final sug = TeamBalancer.suggest(pool, count: 2, random: Random(5));
      expect(sug, isNotEmpty);
      expect(sug.first.a.length, 11);
      expect(sug.first.b.length, 11);
    });

    test('número ímpar de jogadores: times com diferença de 1', () {
      final pool = [for (int i = 0; i < 9; i++) _p('j$i', 60.0 + i * 4)];
      final best = TeamBalancer.best(pool, random: Random(9));
      expect((best.a.length - best.b.length).abs(), 1);
    });
  });

  group('TeamBalancer.fill', () {
    test('respeita as vagas e não duplica jogadores', () {
      final res = TeamBalancer.fill(
        stayersA: [_p('a', 80), _p('b', 70)],
        stayersB: [_p('c', 90), _p('d', 60)],
        entering: [_p('e', 85), _p('f', 65)],
        capA: 1,
        capB: 1,
        random: Random(1),
      );
      expect(res.toA.length, 1);
      expect(res.toB.length, 1);
      expect({...res.toA, ...res.toB}.length, 2);
    });

    test('times vazios + 6 entrando = 3 x 3 equilibrado', () {
      final entering = [
        _p('a', 90), _p('b', 80), _p('c', 70), //
        _p('d', 60), _p('e', 85), _p('f', 75),
      ];
      final res = TeamBalancer.fill(
        stayersA: [],
        stayersB: [],
        entering: entering,
        capA: 3,
        capB: 3,
        random: Random(4),
        tolerance: 0,
      );
      expect(res.toA.length, 3);
      expect(res.toB.length, 3);
      double mean(List<BalancePlayer> l) =>
          l.map((p) => p.rating).reduce((x, y) => x + y) / l.length;
      expect((mean(res.toA) - mean(res.toB)).abs(), lessThan(3.0));
    });

    test('compensa um time forte que ficou em campo', () {
      // Time A ficou com estrelas; o melhor dos novos deve ir pro time B.
      final res = TeamBalancer.fill(
        stayersA: [_p('a1', 90), _p('a2', 88)],
        stayersB: [_p('b1', 60), _p('b2', 58)],
        entering: [_p('n1', 85), _p('n2', 55)],
        capA: 1,
        capB: 1,
        random: Random(1),
        tolerance: 0,
      );
      expect(res.toB.single.id, 'n1');
      expect(res.toA.single.id, 'n2');
    });

    test('menos jogadores que vagas: usa o plano B sem estourar vagas', () {
      final res = TeamBalancer.fill(
        stayersA: [_p('a', 80)],
        stayersB: [_p('b', 70)],
        entering: [_p('n', 75)],
        capA: 2,
        capB: 2,
        random: Random(1),
      );
      expect(res.toA.length + res.toB.length, 1);
    });
  });

  group('simulação', () {
    test('o balanceador novo é bem melhor que o sorteio puro', () {
      final roster = [
        for (int i = 0; i < 14; i++) _p('j$i', 62.0 + i * 2.3),
      ];
      final stats = TeamBalancer.simulate(
        roster,
        teamSize: 5,
        runs: 100,
        random: Random(42),
      );
      double meanOf(DrawStrategy s) =>
          stats.firstWhere((x) => x.strategy == s).meanDiff;
      expect(meanOf(DrawStrategy.nearOptimalRandom),
          lessThan(meanOf(DrawStrategy.random) / 2));
      expect(meanOf(DrawStrategy.optimal),
          lessThanOrEqualTo(meanOf(DrawStrategy.nearOptimalRandom)));
    });
  });

  group('desistência', () {
    test('activePlayers tira quem desistiu', () {
      final present = [_m('a'), _m('b', gaveUp: true), _m('c')];
      expect(activePlayers(present).map((p) => p['id']), ['a', 'c']);
    });

    test('waitingPlayers = ativos fora dos times', () {
      final present = [
        _m('a'), _m('b'), _m('c', gaveUp: true), _m('d'), _m('e'), //
      ];
      final waiting = waitingPlayers(
        present,
        [_m('a')],
        [_m('b')],
        (p) => p['id'].toString(),
      );
      expect(waiting.map((p) => p['id']), ['d', 'e']);
    });

    test('quem desistiu nunca entra num sorteio montado pelo pool ativo', () {
      final present = [
        for (int i = 0; i < 12; i++) _m('j$i', gaveUp: i == 3 || i == 7),
      ];
      final pool = activePlayers(present)
          .map((p) => BalancePlayer(p['id'] as String, 70))
          .toList();
      for (int seed = 0; seed < 10; seed++) {
        final s = TeamBalancer.suggest(pool, random: Random(seed)).first;
        final ids = [...s.a, ...s.b].map((p) => p.id).toSet();
        expect(ids.contains('j3'), isFalse);
        expect(ids.contains('j7'), isFalse);
      }
    });
  });

  group('overall na partida', () {
    test('playerOverallOf prefere o overall do snapshot', () {
      expect(playerOverallOf({'overall': 88, 'rating': 5.0}), 88.0);
    });

    test('sem overall, calcula com nota do app + atributos da comunidade', () {
      final p = {
        'rating': 8.0,
        'community_pac': 90,
        'community_sho': 90,
        'community_pas': 90,
        'community_dri': 90,
        'community_def': 90,
        'community_phy': 90,
      };
      expect(
        playerOverallOf(p),
        calculateOverall(
          appRating10: 8.0,
          community: CommunityAttributes.fromMap(p),
        ).toDouble(),
      );
    });
  });
}

// Simulador de balanceamento de times.
//
// Uso (na raiz do projeto):
//   dart run tool/simulate_balance.dart
//   dart run tool/simulate_balance.dart --team-size=6 --runs=2000
//   dart run tool/simulate_balance.dart --ratings=92,89,87,86,85,83,80,78,77,75,74,72
//
// O que faz: simula milhares de peladas. Em cada uma, sorteia quem apareceu
// (2 x team-size jogadores do elenco) e aplica TODAS as estratégias de sorteio
// no mesmo grupo, medindo a diferença de média de Overall entre os dois times.
// Quanto menor a diferença, mais equilibrado.
import 'dart:math';

import 'package:app_do_fut/utils/team_balancer.dart';

const List<double> _defaultRoster = [
  92, 89, 87, 86, 85, 83, 80, 78, 77, 75, 74, 72, 70, 68, 66, 63, //
];

String _arg(List<String> args, String name, String fallback) {
  for (final a in args) {
    if (a.startsWith('--$name=')) return a.substring(name.length + 3);
  }
  return fallback;
}

void main(List<String> args) {
  final teamSize = int.parse(_arg(args, 'team-size', '5'));
  final runs = int.parse(_arg(args, 'runs', '1000'));
  final seed = int.parse(_arg(args, 'seed', '42'));
  final ratingsArg = _arg(args, 'ratings', '');
  final ratings = ratingsArg.isEmpty
      ? _defaultRoster
      : ratingsArg.split(',').map((e) => double.parse(e.trim())).toList();

  final roster = [
    for (int i = 0; i < ratings.length; i++)
      BalancePlayer('J${i + 1}', ratings[i]),
  ];

  print('Elenco: ${ratings.length} jogadores | $teamSize x $teamSize | '
      '$runs peladas simuladas\n');

  final stats = TeamBalancer.simulate(
    roster,
    teamSize: teamSize,
    runs: runs,
    random: Random(seed),
  );

  String pad(String s, int n) => s.padRight(n);
  print('${pad('Estratégia', 32)}${pad('Dif. média', 12)}${pad('P90', 8)}'
      '${pad('Máx', 8)}${pad('≤1 pt', 8)}${pad('≤2 pts', 8)}Gap elites');
  for (final s in stats) {
    print('${pad(drawStrategyLabel(s.strategy), 32)}'
        '${pad(s.meanDiff.toStringAsFixed(2), 12)}'
        '${pad(s.p90Diff.toStringAsFixed(2), 8)}'
        '${pad(s.maxDiff.toStringAsFixed(2), 8)}'
        '${pad('${s.pctWithin1.toStringAsFixed(0)}%', 8)}'
        '${pad('${s.pctWithin2.toStringAsFixed(0)}%', 8)}'
        '${s.meanEliteGap.toStringAsFixed(2)}');
  }
  print('\nDif. = diferença entre a média de Overall dos dois times '
      '(pontos de Overall).');
}

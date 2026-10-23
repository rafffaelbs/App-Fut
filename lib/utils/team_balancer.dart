import 'dart:math';

/// ============================================================
/// team_balancer.dart
/// ============================================================
/// Balanceamento de times SEM dependência de Flutter (só dart:math), para
/// poder ser testado e simulado pela linha de comando:
///
///   dart run tool/simulate_balance.dart
///
/// A "força" de cada jogador é o Overall (0-99) -- o mesmo que aparece no card.
///
/// Como funciona:
///  * Até 20 jogadores no sorteio, o balanceador ENUMERA todas as divisões
///    possíveis (10v10 = 92.378 combinações, instantâneo) e pontua cada uma.
///    Ou seja: acha o time realmente mais equilibrado, não um "chute bom".
///  * Acima de 20, usa muitos sorteios aleatórios + melhoria por trocas.
///  * Em vez de sempre devolver o melhor (que repetiria os mesmos times),
///    [TeamBalancer.suggest] sorteia entre as divisões "quase tão boas quanto
///    a melhor" (dentro de uma tolerância), evitando repetir o último sorteio.
/// ============================================================

/// Jogador visto pelo balanceador: só id + força.
class BalancePlayer {
  final String id;

  /// Overall (0-99).
  final double rating;

  const BalancePlayer(this.id, this.rating);

  @override
  String toString() => '$id($rating)';
}

/// Pesos da nota de desequilíbrio (quanto MENOR o score, mais equilibrado).
class BalanceWeights {
  /// Diferença entre a média dos dois times.
  final double mean;

  /// Diferença entre o melhor jogador de cada time (evita "time do craque").
  final double top;

  /// Diferença de dispersão (desvio-padrão): evita um time só de medianos
  /// contra outro de estrelas + pernas de pau com a mesma média.
  final double spread;

  /// Diferença na quantidade de elites (overall >= [eliteThreshold]).
  final double elite;

  /// Overall a partir do qual o jogador conta como elite (= faixa Elite do card).
  final double eliteThreshold;

  const BalanceWeights({
    this.mean = 1.0,
    this.top = 0.25,
    this.spread = 0.25,
    this.elite = 1.5,
    this.eliteThreshold = 85,
  });
}

/// Uma divisão em dois times.
class SplitResult {
  final List<BalancePlayer> a;
  final List<BalancePlayer> b;
  final double meanA;
  final double meanB;
  final double score;
  final int eliteA;
  final int eliteB;

  const SplitResult({
    required this.a,
    required this.b,
    required this.meanA,
    required this.meanB,
    required this.score,
    required this.eliteA,
    required this.eliteB,
  });

  /// Diferença absoluta de média entre os times (em pontos de Overall).
  double get diff => (meanA - meanB).abs();

  int get eliteGap => (eliteA - eliteB).abs();

  /// Chave independente de cor: mesmos jogadores com lados trocados = mesma chave.
  String get key {
    final ka = (a.map((p) => p.id).toList()..sort()).join(',');
    final kb = (b.map((p) => p.id).toList()..sort()).join(',');
    return ka.compareTo(kb) <= 0 ? '$ka|$kb' : '$kb|$ka';
  }

  SplitResult swapped() => SplitResult(
        a: b,
        b: a,
        meanA: meanB,
        meanB: meanA,
        score: score,
        eliteA: eliteB,
        eliteB: eliteA,
      );
}

/// Estratégias de sorteio comparáveis na simulação.
enum DrawStrategy {
  /// Embaralha e divide ao meio (sorteio "puro").
  random,

  /// O algoritmo antigo do app: faixas de nota + embaralha + 40% de inverter.
  legacyBands,

  /// Ordena do melhor ao pior e distribui em "cobrinha" (A B B A A B B A...).
  snake,

  /// Ordena e sempre põe o próximo no time de menor soma.
  greedy,

  /// Sorteia entre as divisões quase ótimas (o que o app passa a usar).
  nearOptimalRandom,

  /// A melhor divisão possível (determinística, repete sempre).
  optimal,
}

String drawStrategyLabel(DrawStrategy s) {
  switch (s) {
    case DrawStrategy.random:
      return 'Aleatório puro';
    case DrawStrategy.legacyBands:
      return 'Antigo (faixas + 40% inverte)';
    case DrawStrategy.snake:
      return 'Cobrinha (A B B A...)';
    case DrawStrategy.greedy:
      return 'Guloso (menor soma)';
    case DrawStrategy.nearOptimalRandom:
      return 'Quase-ótimo sorteado (novo)';
    case DrawStrategy.optimal:
      return 'Ótimo (sempre o melhor)';
  }
}

/// Estatística de uma estratégia numa simulação.
class StrategyStats {
  final DrawStrategy strategy;

  /// Média da diferença de média entre os times (pontos de Overall).
  final double meanDiff;
  final double p90Diff;
  final double maxDiff;

  /// % de sorteios com diferença <= 1 ponto de Overall.
  final double pctWithin1;

  /// % de sorteios com diferença <= 2 pontos.
  final double pctWithin2;

  /// Média da diferença na quantidade de elites entre os times.
  final double meanEliteGap;

  const StrategyStats({
    required this.strategy,
    required this.meanDiff,
    required this.p90Diff,
    required this.maxDiff,
    required this.pctWithin1,
    required this.pctWithin2,
    required this.meanEliteGap,
  });
}

class TeamBalancer {
  TeamBalancer._();

  /// Limite para enumerar todas as divisões (2^20 máscaras no pior caso).
  static const int maxEnumerable = 20;

  // ───────────────────────── API principal ─────────────────────────

  /// Devolve até [count] sugestões de divisão, da mais equilibrada pra menos.
  ///
  /// * [tolerance]: quão pior que a melhor divisão (em pontos de score,
  ///   ~pontos de Overall de diferença de média) uma sugestão pode ser.
  ///   0 = só a melhor; 1.0 = padrão (variedade com qualidade);
  ///   2.0+ = mais aleatório.
  /// * [excludeKeys]: divisões (ver [SplitResult.key]) que não podem sair,
  ///   p.ex. o último sorteio.
  /// * Os lados (vermelho/branco) são sorteados em cada sugestão.
  static List<SplitResult> suggest(
    List<BalancePlayer> pool, {
    int count = 3,
    double tolerance = 1.0,
    Set<String> excludeKeys = const {},
    Random? random,
    BalanceWeights weights = const BalanceWeights(),
  }) {
    final rnd = random ?? Random();
    if (pool.length < 2) return [];

    final candidates = _candidates(pool, weights, rnd, tolerance);
    if (candidates.isEmpty) return [];

    // Embaralha para variar quais "quase ótimas" aparecem.
    final shuffled = List<_Cand>.from(candidates)..shuffle(rnd);

    final picked = <_Cand>[];
    final pickedKeys = <String>{};

    void pass(int minHamming) {
      for (final c in shuffled) {
        if (picked.length >= count) return;
        final key = _keyOf(pool, c.inA);
        if (excludeKeys.contains(key) || pickedKeys.contains(key)) continue;
        final diverse =
            picked.every((p) => _hamming(p.inA, c.inA) >= minHamming);
        if (!diverse) continue;
        picked.add(c);
        pickedKeys.add(key);
      }
    }

    // 1º tenta sugestões que diferem em pelo menos 2 jogadores trocados;
    // se faltar, aceita diferença de 1 troca.
    pass(4);
    if (picked.length < count) pass(2);

    // Tudo excluído? Devolve a melhor mesmo assim (melhor repetir que travar).
    if (picked.isEmpty) {
      final best = candidates.reduce((x, y) => x.score <= y.score ? x : y);
      picked.add(best);
    }

    picked.sort((x, y) => x.score.compareTo(y.score));
    return picked.map((c) {
      final r = _toResult(pool, c.inA, c.score, weights);
      return rnd.nextBool() ? r.swapped() : r;
    }).toList();
  }

  /// A divisão mais equilibrada possível (determinística).
  static SplitResult best(
    List<BalancePlayer> pool, {
    Random? random,
    BalanceWeights weights = const BalanceWeights(),
  }) {
    final r = suggest(pool,
        count: 1, tolerance: 0, random: random, weights: weights);
    return r.first;
  }


  // ───────────────────────── Completar times parciais ─────────────────────────

  /// Distribui [entering] entre dois times que já têm [stayersA]/[stayersB]
  /// (quem ficou em campo), respeitando as vagas [capA]/[capB].
  ///
  /// Serve para "ambos saem", empate, sequência de vitórias e "dividir
  /// vencedor": em vez de preencher na ordem de chegada, escolhe a combinação
  /// que deixa os dois times mais equilibrados (sorteando entre as quase
  /// ótimas, dentro de [tolerance]).
  static FillResult fill({
    required List<BalancePlayer> stayersA,
    required List<BalancePlayer> stayersB,
    required List<BalancePlayer> entering,
    required int capA,
    required int capB,
    Random? random,
    BalanceWeights weights = const BalanceWeights(),
    double tolerance = 0.5,
  }) {
    final rnd = random ?? Random();
    final m = entering.length;
    if (m == 0) return const FillResult([], []);

    final canEnumerate = m <= maxEnumerable &&
        capA + capB == m &&
        capA >= 0 &&
        capB >= 0 &&
        (stayersA.length + capA) > 0 &&
        (stayersB.length + capB) > 0;

    if (!canEnumerate) {
      // Plano B (poucos jogadores / vagas que não fecham): guloso por soma.
      final order = List<BalancePlayer>.from(entering)
        ..sort((x, y) => y.rating.compareTo(x.rating));
      double sumA = stayersA.fold(0.0, (s, p) => s + p.rating);
      double sumB = stayersB.fold(0.0, (s, p) => s + p.rating);
      int nA = stayersA.length, nB = stayersB.length;
      int leftA = capA, leftB = capB;
      final toA = <BalancePlayer>[], toB = <BalancePlayer>[];
      for (final p in order) {
        final okA = leftA > 0, okB = leftB > 0;
        if (!okA && !okB) break;
        final meanA = nA == 0 ? 0 : sumA / nA;
        final meanB = nB == 0 ? 0 : sumB / nB;
        final goA = okA && (!okB || meanA <= meanB);
        if (goA) {
          toA.add(p);
          sumA += p.rating;
          nA++;
          leftA--;
        } else {
          toB.add(p);
          sumB += p.rating;
          nB++;
          leftB--;
        }
      }
      return FillResult(toA, toB);
    }

    final r = <double>[
      ...stayersA.map((p) => p.rating),
      ...stayersB.map((p) => p.rating),
      ...entering.map((p) => p.rating),
    ];
    final base = stayersA.length + stayersB.length;
    final inA = List<bool>.filled(r.length, false);
    for (int i = 0; i < stayersA.length; i++) {
      inA[i] = true;
    }

    final masks = <int>[];
    final scores = <double>[];
    double best = double.infinity;
    for (int mask = 0; mask < (1 << m); mask++) {
      if (_popcount(mask) != capA) continue;
      for (int i = 0; i < m; i++) {
        inA[base + i] = (mask >> i) & 1 == 1;
      }
      final sc = _scoreAssign(r, inA, weights);
      masks.add(mask);
      scores.add(sc);
      if (sc < best) best = sc;
    }
    if (masks.isEmpty) return const FillResult([], []);

    final good = <int>[];
    for (int k = 0; k < masks.length; k++) {
      if (scores[k] <= best + tolerance + 1e-9) good.add(masks[k]);
    }
    final chosen = good[rnd.nextInt(good.length)];
    final toA = <BalancePlayer>[], toB = <BalancePlayer>[];
    for (int i = 0; i < m; i++) {
      ((chosen >> i) & 1 == 1 ? toA : toB).add(entering[i]);
    }
    return FillResult(toA, toB);
  }

  // ───────────────────────── Estratégias (simulação) ─────────────────────────

  /// Aplica uma [DrawStrategy] a um grupo de jogadores.
  static SplitResult drawWith(
    DrawStrategy strategy,
    List<BalancePlayer> pool, {
    Random? random,
    BalanceWeights weights = const BalanceWeights(),
    double legacyBandWidth = 5.0,
  }) {
    final rnd = random ?? Random();
    final n = pool.length;
    final sizeA = (n + 1) ~/ 2;

    List<bool> assign(List<int> aIdx) {
      final inA = List<bool>.filled(n, false);
      for (final i in aIdx) {
        inA[i] = true;
      }
      return inA;
    }

    switch (strategy) {
      case DrawStrategy.random:
        {
          final idx = List<int>.generate(n, (i) => i)..shuffle(rnd);
          return _toResult(pool, assign(idx.take(sizeA).toList()), 0, weights);
        }

      case DrawStrategy.legacyBands:
        return _legacyBands(pool, rnd, legacyBandWidth, weights);

      case DrawStrategy.snake:
        {
          final idx = _sortedDesc(pool);
          final aIdx = <int>[];
          for (int k = 0; k < n; k++) {
            final round = k ~/ 2;
            final firstOfPair = k % 2 == 0;
            // A B | B A | A B | B A ...
            final toA = round % 2 == 0 ? firstOfPair : !firstOfPair;
            if (toA) aIdx.add(idx[k]);
          }
          return _fixSizes(pool, aIdx, sizeA, weights);
        }

      case DrawStrategy.greedy:
        {
          final idx = _sortedDesc(pool);
          final aIdx = <int>[];
          double sumA = 0, sumB = 0;
          int nA = 0, nB = 0;
          for (final i in idx) {
            final canA = nA < sizeA;
            final canB = nB < n - sizeA;
            final toA = canA && (!canB || sumA <= sumB);
            if (toA) {
              aIdx.add(i);
              sumA += pool[i].rating;
              nA++;
            } else {
              sumB += pool[i].rating;
              nB++;
            }
          }
          return _toResult(pool, assign(aIdx), 0, weights);
        }

      case DrawStrategy.nearOptimalRandom:
        return suggest(pool,
                count: 1, tolerance: 1.0, random: rnd, weights: weights)
            .first;

      case DrawStrategy.optimal:
        return suggest(pool,
                count: 1, tolerance: 0, random: rnd, weights: weights)
            .first;
    }
  }

  /// Simula [runs] peladas. A cada rodada sorteia quem apareceu (um subconjunto
  /// de [roster] com `2 * teamSize` jogadores, ou todos se houver menos) e
  /// aplica TODAS as estratégias nesse mesmo grupo, para comparação justa.
  static List<StrategyStats> simulate(
    List<BalancePlayer> roster, {
    int teamSize = 5,
    int runs = 500,
    Random? random,
    BalanceWeights weights = const BalanceWeights(),
    List<DrawStrategy> strategies = DrawStrategy.values,
  }) {
    final rnd = random ?? Random(42);
    final perTeam = min(teamSize * 2, roster.length);
    final diffs = {for (final s in strategies) s: <double>[]};
    final elites = {for (final s in strategies) s: <int>[]};

    for (int run = 0; run < runs; run++) {
      final shuffled = List<BalancePlayer>.from(roster)..shuffle(rnd);
      final pool = shuffled.take(perTeam).toList();
      for (final s in strategies) {
        final r = drawWith(s, pool, random: rnd, weights: weights);
        diffs[s]!.add(r.diff);
        elites[s]!.add(r.eliteGap);
      }
    }

    return strategies.map((s) {
      final d = List<double>.from(diffs[s]!)..sort();
      final mean = d.reduce((x, y) => x + y) / d.length;
      final p90 = d[min(d.length - 1, (d.length * 0.9).floor())];
      final within1 = d.where((x) => x <= 1.0).length / d.length * 100;
      final within2 = d.where((x) => x <= 2.0).length / d.length * 100;
      final eliteMean = elites[s]!.reduce((x, y) => x + y) / elites[s]!.length;
      return StrategyStats(
        strategy: s,
        meanDiff: mean,
        p90Diff: p90,
        maxDiff: d.last,
        pctWithin1: within1,
        pctWithin2: within2,
        meanEliteGap: eliteMean,
      );
    }).toList();
  }

  // ───────────────────────── Internos ─────────────────────────

  static List<_Cand> _candidates(
    List<BalancePlayer> pool,
    BalanceWeights w,
    Random rnd,
    double tolerance,
  ) {
    final n = pool.length;
    final r = pool.map((p) => p.rating).toList();
    final sizeA = (n + 1) ~/ 2;

    if (n <= maxEnumerable) {
      return _enumerate(r, n, sizeA, w, tolerance);
    }
    return _sampled(r, n, sizeA, w, rnd, tolerance);
  }

  /// Todas as divisões possíveis (com n par, o jogador 0 fica sempre no time A
  /// para não contar a mesma divisão duas vezes com cores trocadas).
  static List<_Cand> _enumerate(
    List<double> r,
    int n,
    int sizeA,
    BalanceWeights w,
    double tolerance,
  ) {
    final fixFirst = n.isEven;
    final total = 1 << n;
    final masks = <int>[];
    final scores = <double>[];
    double bestScore = double.infinity;
    final inA = List<bool>.filled(n, false);

    for (int mask = fixFirst ? 1 : 0; mask < total; mask += fixFirst ? 2 : 1) {
      if (_popcount(mask) != sizeA) continue;
      for (int i = 0; i < n; i++) {
        inA[i] = (mask >> i) & 1 == 1;
      }
      final s = _scoreAssign(r, inA, w);
      masks.add(mask);
      scores.add(s);
      if (s < bestScore) bestScore = s;
    }

    final out = <_Cand>[];
    for (int k = 0; k < masks.length; k++) {
      if (scores[k] <= bestScore + tolerance + 1e-9) {
        out.add(_Cand(
          List<bool>.generate(n, (i) => (masks[k] >> i) & 1 == 1),
          scores[k],
        ));
      }
    }
    return out;
  }

  /// Para grupos grandes: vários sorteios aleatórios melhorados por trocas.
  static List<_Cand> _sampled(
    List<double> r,
    int n,
    int sizeA,
    BalanceWeights w,
    Random rnd,
    double tolerance,
  ) {
    final found = <String, _Cand>{};
    double bestScore = double.infinity;

    for (int restart = 0; restart < 400; restart++) {
      final idx = List<int>.generate(n, (i) => i)..shuffle(rnd);
      final inA = List<bool>.filled(n, false);
      for (final i in idx.take(sizeA)) {
        inA[i] = true;
      }
      var score = _scoreAssign(r, inA, w);

      // Melhoria por trocas A<->B até não melhorar.
      bool improved = true;
      while (improved) {
        improved = false;
        for (int i = 0; i < n; i++) {
          if (!inA[i]) continue;
          for (int j = 0; j < n; j++) {
            if (inA[j]) continue;
            inA[i] = false;
            inA[j] = true;
            final s = _scoreAssign(r, inA, w);
            if (s + 1e-9 < score) {
              score = s;
              improved = true;
              break;
            }
            inA[i] = true;
            inA[j] = false;
          }
          if (improved) break;
        }
      }

      final key = inA.map((b) => b ? '1' : '0').join();
      final mirrorKey = inA.map((b) => b ? '0' : '1').join();
      if (!found.containsKey(key) && !found.containsKey(mirrorKey)) {
        found[key] = _Cand(List<bool>.from(inA), score);
      }
      if (score < bestScore) bestScore = score;
    }

    return found.values
        .where((c) => c.score <= bestScore + tolerance + 1e-9)
        .toList();
  }

  /// Score de desequilíbrio de uma atribuição (menor = melhor). Sem alocação.
  static double _scoreAssign(List<double> r, List<bool> inA, BalanceWeights w) {
    double sumA = 0, sumB = 0, sqA = 0, sqB = 0;
    double topA = -1e9, topB = -1e9;
    int nA = 0, nB = 0, eA = 0, eB = 0;
    for (int i = 0; i < r.length; i++) {
      final v = r[i];
      final isElite = v >= w.eliteThreshold;
      if (inA[i]) {
        sumA += v;
        sqA += v * v;
        nA++;
        if (v > topA) topA = v;
        if (isElite) eA++;
      } else {
        sumB += v;
        sqB += v * v;
        nB++;
        if (v > topB) topB = v;
        if (isElite) eB++;
      }
    }
    if (nA == 0 || nB == 0) return double.infinity;
    final mA = sumA / nA, mB = sumB / nB;
    final sdA = sqrt(max(0.0, sqA / nA - mA * mA));
    final sdB = sqrt(max(0.0, sqB / nB - mB * mB));
    return w.mean * (mA - mB).abs() +
        w.top * (topA - topB).abs() +
        w.spread * (sdA - sdB).abs() +
        w.elite * (eA - eB).abs();
  }

  static SplitResult _toResult(
    List<BalancePlayer> pool,
    List<bool> inA,
    double score,
    BalanceWeights w,
  ) {
    final a = <BalancePlayer>[];
    final b = <BalancePlayer>[];
    for (int i = 0; i < pool.length; i++) {
      (inA[i] ? a : b).add(pool[i]);
    }
    double mean(List<BalancePlayer> l) =>
        l.isEmpty ? 0 : l.map((p) => p.rating).reduce((x, y) => x + y) / l.length;
    int elites(List<BalancePlayer> l) =>
        l.where((p) => p.rating >= w.eliteThreshold).length;
    return SplitResult(
      a: a,
      b: b,
      meanA: mean(a),
      meanB: mean(b),
      score: score == 0 ? _scoreAssign(pool.map((p) => p.rating).toList(), inA, w) : score,
      eliteA: elites(a),
      eliteB: elites(b),
    );
  }

  static String _keyOf(List<BalancePlayer> pool, List<bool> inA) {
    final ka = <String>[];
    final kb = <String>[];
    for (int i = 0; i < pool.length; i++) {
      (inA[i] ? ka : kb).add(pool[i].id);
    }
    ka.sort();
    kb.sort();
    final sa = ka.join(','), sb = kb.join(',');
    return sa.compareTo(sb) <= 0 ? '$sa|$sb' : '$sb|$sa';
  }

  static int _hamming(List<bool> x, List<bool> y) {
    int d = 0;
    for (int i = 0; i < x.length; i++) {
      if (x[i] != y[i]) d++;
    }
    return d;
  }

  static int _popcount(int v) {
    int c = 0;
    while (v != 0) {
      v &= v - 1;
      c++;
    }
    return c;
  }

  static List<int> _sortedDesc(List<BalancePlayer> pool) {
    final idx = List<int>.generate(pool.length, (i) => i);
    idx.sort((x, y) => pool[y].rating.compareTo(pool[x].rating));
    return idx;
  }

  /// Garante tamanhos (n+1)/2 e n/2 mexendo no mínimo possível.
  static SplitResult _fixSizes(
    List<BalancePlayer> pool,
    List<int> aIdx,
    int sizeA,
    BalanceWeights w,
  ) {
    final inA = List<bool>.filled(pool.length, false);
    for (final i in aIdx) {
      inA[i] = true;
    }
    int countA() => inA.where((v) => v).length;
    // Move os piores (mais ao fim da ordenação) até acertar o tamanho.
    final order = _sortedDesc(pool).reversed.toList();
    while (countA() > sizeA) {
      final i = order.firstWhere((k) => inA[k]);
      inA[i] = false;
    }
    while (countA() < sizeA) {
      final i = order.firstWhere((k) => !inA[k]);
      inA[i] = true;
    }
    return _toResult(pool, inA, 0, w);
  }

  /// Port fiel do `_draftOneSplit` antigo da match_screen (faixas + shuffle +
  /// 40% de chance de inverter a escolha "ideal"). Só existe para a simulação
  /// poder compará-lo com as estratégias novas.
  static SplitResult _legacyBands(
    List<BalancePlayer> pool,
    Random rnd,
    double bandWidth,
    BalanceWeights w,
  ) {
    final n = pool.length;
    final perTeam = (n + 1) ~/ 2;
    final byBand = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      final band = (pool[i].rating / bandWidth).floor();
      byBand.putIfAbsent(band, () => []).add(i);
    }
    final bands = byBand.keys.toList()..sort((x, y) => y.compareTo(x));
    final ordered = <int>[];
    for (final band in bands) {
      final g = byBand[band]!..shuffle(rnd);
      ordered.addAll(g);
    }

    final aIdx = <int>[];
    int nA = 0, nB = 0;
    double sumA = 0, sumB = 0;
    final sizeB = n - perTeam;
    for (final i in ordered) {
      final v = pool[i].rating;
      if (nA < perTeam && nB < sizeB) {
        bool pickA = sumA <= sumB;
        if (rnd.nextDouble() < 0.4) pickA = !pickA;
        if (pickA) {
          aIdx.add(i);
          sumA += v;
          nA++;
        } else {
          sumB += v;
          nB++;
        }
      } else if (nA < perTeam) {
        aIdx.add(i);
        sumA += v;
        nA++;
      } else {
        sumB += v;
        nB++;
      }
    }
    final inA = List<bool>.filled(n, false);
    for (final i in aIdx) {
      inA[i] = true;
    }
    return _toResult(pool, inA, 0, w);
  }
}

/// Quem entra em cada time ao completar vagas ([TeamBalancer.fill]).
class FillResult {
  final List<BalancePlayer> toA;
  final List<BalancePlayer> toB;
  const FillResult(this.toA, this.toB);
}

class _Cand {
  final List<bool> inA;
  final double score;
  const _Cand(this.inA, this.score);
}

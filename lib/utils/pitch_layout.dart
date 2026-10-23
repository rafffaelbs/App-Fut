import 'dart:math' as math;
import 'dart:ui';

import '../widgets/player/fifa_card.dart' show CardDensity;
import 'tactical_formation.dart';

/// Quais times aparecem no campo (zoom de time).
enum PitchFocus { both, red, white }

/// Uma carta posicionada no campo.
///
/// [rect] é a carta; [itemRect] inclui a trilha de eventos abaixo dela e é o
/// que não pode colidir com nenhum outro item.
class PitchSlotRect {
  final bool isRed;
  final bool isGk;

  /// Índice do jogador de linha no time (`-1` para o goleiro).
  final int index;
  final Rect rect;
  final Rect itemRect;
  final CardDensity density;

  const PitchSlotRect({
    required this.isRed,
    required this.isGk,
    required this.index,
    required this.rect,
    required this.itemRect,
    required this.density,
  });
}

class PitchLayoutResult {
  final List<PitchSlotRect> slots;
  final CardDensity density;
  final double scale;
  const PitchLayoutResult(this.slots, this.density, [this.scale = 1]);
}

/// Cálculo puro (sem widgets) de onde cada carta fica no campo, garantindo
/// que nada se sobreponha (docs/design/03-tela-partida.md §4.5).
///
/// O campo tem y = 0 no fundo (gol do time vermelho) e y = 1 na frente (gol
/// do time branco). Cada time vive numa metade, fora da zona do meio.
class PitchLayout {
  PitchLayout._();

  /// Faixa de y de cada metade (fração da altura do campo).
  static const redZone = (top: 0.06, bottom: 0.44);
  static const whiteZone = (top: 0.56, bottom: 0.94);
  static const _focusZone = (top: 0.07, bottom: 0.93);

  /// Folga lateral entre cartas e espaço da trilha de eventos.
  static const double gap = 8;
  static const double vGap = 4;
  static const double eventTrail = 14;

  static Size cardSize(CardDensity d, [double scale = 1]) {
    final b = _baseSize(d);
    return Size(b.width * scale, b.height * scale);
  }

  /// Escalas tentadas da maior para a menor (carta M no campo). O piso 1.14
  /// (× 0.88 de profundidade) mantém os textos da carta em 10sp ou mais.
  static const cardScales = [1.55, 1.4, 1.27, 1.14];

  static Size _baseSize(CardDensity d) {
    switch (d) {
      case CardDensity.small:
        return const Size(52, 62);
      case CardDensity.medium:
        return const Size(60, 84);
      case CardDensity.large:
      case CardDensity.full:
        return const Size(76, 106);
    }
  }

  /// Densidade preferida do formato em retrato (tabela 4.5).
  static CardDensity preferredDensity(int lineCount) =>
      lineCount > 7 ? CardDensity.small : CardDensity.medium;

  /// Escala de largura do gramado: mais estreito ao fundo (design 4.5).
  static double widthScale(double t) => lerpDouble(0.78, 1.0, t.clamp(0, 1))!;

  /// Escala da carta: menor ao fundo.
  static double depthScale(double t) => lerpDouble(0.88, 1.0, t.clamp(0, 1))!;

  /// Altura mínima do campo para que a densidade preferida caiba, sem
  /// sobreposição. Usada como piso quando o espaço disponível é menor.
  static double minHeight(int lineCount,
      {CardDensity? density, List<int>? formation, double? scale}) {
    final d = density ?? preferredDensity(lineCount);
    scale ??= d == CardDensity.medium ? cardScales.last : 1;
    final rows = (formation ?? formationRows(lineCount)).length + 1; // + goleiro
    final item = cardSize(d, scale).height + eventTrail;
    final zone = redZone.bottom - redZone.top;
    return (((rows - 1) * (item + vGap) + item + 2) / zone).ceilToDouble();
  }

  /// Tamanhos tentados, do maior para o menor. Cartas nunca viram chip por
  /// falta de espaço: o campo cresce. Chip só por escolha ou 11×11.
  static List<({CardDensity density, double scale})> candidates(int lineCount,
          {bool chips = false}) =>
      chips || lineCount > 7
          ? const [(density: CardDensity.small, scale: 1.0)]
          : [
              for (final s in cardScales)
                (density: CardDensity.medium, scale: s),
            ];

  static PitchLayoutResult compute({
    required int lineCount,
    required Size field,
    PitchFocus focus = PitchFocus.both,
    List<int>? formation,
    bool chips = false,
  }) {
    final order = candidates(lineCount, chips: chips);
    for (final c in order) {
      final r = _layoutWith(c.density, c.scale, lineCount, field, focus,
          formation: formation);
      if (r != null) return r;
    }
    final c = order.last;
    return _layoutWith(c.density, c.scale, lineCount, field, focus,
        formation: formation, force: true)!;
  }

  static PitchLayoutResult? _layoutWith(
    CardDensity d,
    double scale,
    int lineCount,
    Size field,
    PitchFocus focus, {
    List<int>? formation,
    bool force = false,
  }) {
    final rows = formation ?? formationRows(lineCount);
    final slots = <PitchSlotRect>[];
    for (final isRed in const [true, false]) {
      if (focus == PitchFocus.red && !isRed) continue;
      if (focus == PitchFocus.white && isRed) continue;
      final zone = focus == PitchFocus.both
          ? (isRed ? redZone : whiteZone)
          : _focusZone;
      final team = _layoutTeam(d, scale, rows, field, zone.top, zone.bottom, isRed);
      if (team == null && !force) return null;
      slots.addAll(team ?? _layoutTeam(d, scale, rows, field, zone.top, zone.bottom, isRed, force: true)!);
    }
    return PitchLayoutResult(slots, d, scale);
  }

  static List<PitchSlotRect>? _layoutTeam(
    CardDensity d,
    double scale,
    List<int> rows,
    Size field,
    double top,
    double bottom,
    bool isRed, {
    bool force = false,
  }) {
    final base = cardSize(d, scale);
    final item = base.height + eventTrail;
    final count = rows.length + 1; // linha 0 = goleiro
    final zt = field.height * top;
    final zb = field.height * bottom;
    final pitch = count == 1 ? 0.0 : (zb - zt - item) / (count - 1);
    if (!force && pitch < item + vGap && count > 1) return null;

    final out = <PitchSlotRect>[];
    var playerIndex = 0;
    for (var k = 0; k < count; k++) {
      // Fileira k: 0 = goleiro, crescente em direção ao meio-campo.
      final itemTop = isRed ? zt + k * pitch : zb - item - k * pitch;
      final cy = itemTop + base.height / 2;
      final t = (cy / field.height).clamp(0.0, 1.0);
      final ws = widthScale(t);
      final ds = depthScale(t);
      final cols = k == 0 ? 1 : rows[k - 1];
      final cw = base.width * ds;
      final ch = base.height * ds;
      final rowW = field.width * ws * 0.94;

      final xs = <double>[
        for (var i = 0; i < cols; i++)
          cols == 1
              ? 0.5
              : cols == 2
                  ? (i == 0 ? 1 / 3 : 2 / 3)
                  : (i + 0.5) / cols,
      ];
      for (var i = 0; i < cols; i++) {
        final cx = field.width * (0.5 + (xs[i] - 0.5) * ws);
        if (!force && i > 0) {
          final prev = field.width * (0.5 + (xs[i - 1] - 0.5) * ws);
          if (cx - prev < cw + gap) return null;
        }
        if (!force && cols > 0 && cw > rowW) return null;
        final rect = Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch);
        out.add(PitchSlotRect(
          isRed: isRed,
          isGk: k == 0,
          index: k == 0 ? -1 : playerIndex++,
          rect: rect,
          itemRect: Rect.fromLTRB(
              rect.left, rect.top, rect.right, rect.bottom + eventTrail),
          density: d,
        ));
      }
    }
    return out;
  }

  /// Verdadeiro se qualquer par de itens se sobrepõe.
  static bool hasOverlap(List<PitchSlotRect> slots) {
    for (var i = 0; i < slots.length; i++) {
      for (var j = i + 1; j < slots.length; j++) {
        if (slots[i].itemRect.overlaps(slots[j].itemRect)) return true;
      }
    }
    return false;
  }

  /// Y mínimo/ máximo ocupado, útil para testes de zona do meio.
  static double maxDeviation(List<PitchSlotRect> s) =>
      s.fold(0.0, (m, e) => math.max(m, e.itemRect.bottom));
}

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

  /// Faixa de y de cada metade (fração da altura do campo no modo vertical).
  static const redZone = (top: 0.06, bottom: 0.44);
  static const whiteZone = (top: 0.56, bottom: 0.94);
  static const _focusZone = (top: 0.07, bottom: 0.93);

  /// Faixa de x de cada metade (fração da largura do campo no modo horizontal).
  static const redZoneH = (left: 0.04, right: 0.46);
  static const whiteZoneH = (left: 0.54, right: 0.96);
  static const _focusZoneH = (left: 0.05, right: 0.95);

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
  static const chipScales = [1.15, 1.0];

  static const cardScalesHorizontal = [1.1, 1.0, 0.9, 0.8, 0.72, 0.65, 0.55, 0.48, 0.42];
  static const chipScalesHorizontal = [1.1, 1.0, 0.9, 0.8, 0.72, 0.65, 0.55, 0.48, 0.42];

  static Size _baseSize(CardDensity d) {
    switch (d) {
      case CardDensity.small:
        return const Size(64, 84);
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

  /// Altura mínima no modo horizontal com base na coluna com mais jogadores.
  static double minHeightHorizontal(int lineCount,
      {CardDensity? density, List<int>? formation, double? scale}) {
    final d = density ?? preferredDensity(lineCount);
    scale ??= cardScalesHorizontal.last;
    final rows = formation ?? formationRows(lineCount);
    final maxCols = rows.isEmpty ? 1 : rows.reduce(math.max);
    final item = cardSize(d, scale).height + eventTrail;
    return (((maxCols - 1) * (item + vGap) + item + 16) / 0.88).ceilToDouble();
  }

  /// Tamanhos tentados, do maior para o menor.
  static List<({CardDensity density, double scale})> candidates(int lineCount,
      {bool chips = false, bool isHorizontal = false}) {
    if (isHorizontal) {
      return chips || lineCount > 7
          ? [
              for (final s in chipScalesHorizontal)
                (density: CardDensity.small, scale: s),
            ]
          : [
              for (final s in cardScalesHorizontal)
                (density: CardDensity.medium, scale: s),
            ];
    }
    return chips || lineCount > 7
        ? [
            for (final s in chipScales)
              (density: CardDensity.small, scale: s),
          ]
        : [
            for (final s in cardScales)
              (density: CardDensity.medium, scale: s),
          ];
  }

  static PitchLayoutResult compute({
    required int lineCount,
    required Size field,
    PitchFocus focus = PitchFocus.both,
    List<int>? formation,
    bool chips = false,
    bool isHorizontal = false,
  }) {
    final order = candidates(lineCount, chips: chips, isHorizontal: isHorizontal);
    for (final c in order) {
      final r = _layoutWith(c.density, c.scale, lineCount, field, focus,
          formation: formation, isHorizontal: isHorizontal);
      if (r != null) return r;
    }
    final c = order.last;
    return _layoutWith(c.density, c.scale, lineCount, field, focus,
        formation: formation, force: true, isHorizontal: isHorizontal)!;
  }

  static PitchLayoutResult? _layoutWith(
    CardDensity d,
    double scale,
    int lineCount,
    Size field,
    PitchFocus focus, {
    List<int>? formation,
    bool force = false,
    bool isHorizontal = false,
  }) {
    final rows = formation ?? formationRows(lineCount);
    final slots = <PitchSlotRect>[];
    for (final isRed in const [true, false]) {
      if (focus == PitchFocus.red && !isRed) continue;
      if (focus == PitchFocus.white && isRed) continue;

      if (isHorizontal) {
        final zone = focus == PitchFocus.both
            ? (isRed ? redZoneH : whiteZoneH)
            : _focusZoneH;
        final team = _layoutTeamHorizontal(
            d, scale, rows, field, zone.left, zone.right, isRed,
            force: force);
        if (team == null && !force) return null;
        slots.addAll(team ??
            _layoutTeamHorizontal(
                d, scale, rows, field, zone.left, zone.right, isRed,
                force: true)!);
      } else {
        final zone = focus == PitchFocus.both
            ? (isRed ? redZone : whiteZone)
            : _focusZone;
        final team =
            _layoutTeam(d, scale, rows, field, zone.top, zone.bottom, isRed);
        if (team == null && !force) return null;
        slots.addAll(team ??
            _layoutTeam(d, scale, rows, field, zone.top, zone.bottom, isRed,
                force: true)!);
      }
    }
    if (!force && hasOverlap(slots)) return null;
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
        final rect =
            Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch);
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

  static List<PitchSlotRect>? _layoutTeamHorizontal(
    CardDensity d,
    double scale,
    List<int> rows,
    Size field,
    double left,
    double right,
    bool isRed, {
    bool force = false,
  }) {
    final base = cardSize(d, scale);
    final itemH = base.height + eventTrail;
    final cw = base.width;
    final ch = base.height;
    final count = rows.length + 1; // linha 0 = goleiro
    final zl = field.width * left;
    final zr = field.width * right;
    final teamW = zr - zl;

    final pitchX = count == 1 ? 0.0 : (teamW - cw) / (count - 1);
    if (!force && pitchX < cw + gap && count > 1) return null;

    final out = <PitchSlotRect>[];
    var playerIndex = 0;

    const topY = 0.06;
    const bottomY = 0.94;
    final availH = field.height * (bottomY - topY);

    for (var k = 0; k < count; k++) {
      // Coluna k: 0 = goleiro, avançando em direção ao meio de campo
      final cx = isRed
          ? zl + cw / 2 + k * pitchX
          : zr - cw / 2 - k * pitchX;

      final cols = k == 0 ? 1 : rows[k - 1];
      if (!force && cols > 1 && (availH - itemH) / (cols - 1) < itemH + vGap) {
        return null;
      }

      for (var i = 0; i < cols; i++) {
        final double cy;
        if (cols == 1) {
          cy = field.height * 0.5;
        } else {
          final step = (availH - itemH) / (cols - 1);
          cy = field.height * topY + itemH / 2 + i * step;
        }

        final rect = Rect.fromCenter(
          center: Offset(cx, cy - eventTrail / 2),
          width: cw,
          height: ch,
        );
        final itemRect = Rect.fromLTRB(
          rect.left,
          rect.top,
          rect.right,
          rect.bottom + eventTrail,
        );

        out.add(PitchSlotRect(
          isRed: isRed,
          isGk: k == 0,
          index: k == 0 ? -1 : playerIndex++,
          rect: rect,
          itemRect: itemRect,
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

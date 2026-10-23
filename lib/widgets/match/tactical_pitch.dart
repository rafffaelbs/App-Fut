import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/overall_calculator.dart';
import '../../utils/pitch_layout.dart';
import '../../utils/player_identity.dart';
import '../../utils/tactical_formation.dart';
import '../player/fifa_card.dart';
import '../shared/player_avatar_frame.dart';

const _emptyStats = {
  'nota': 0.0,
  'goals': 0,
  'assists': 0,
  'ownGoals': 0,
  'yellow': 0,
  'red': 0,
};

/// Campo tático em perspectiva com cartas "billboard": o gramado é um
/// trapézio, mas as cartas ficam de frente e são posicionadas por
/// [PitchLayout], que garante que nenhuma se sobreponha.
///
/// Toque na faixa de um time faz zoom nele; toque de novo (ou duplo toque no
/// campo) volta à visão geral. O foco é estado local: não reconstrói a tela.
class TacticalPitch extends StatefulWidget {
  final int teamSize;
  final List<Map<String, dynamic>> teamRed;
  final List<Map<String, dynamic>> teamWhite;
  final Map<String, dynamic>? gkRed;
  final Map<String, dynamic>? gkWhite;
  final Map<String, Map<String, dynamic>> allStats;
  final String? motmPlayerId;
  final void Function(Map<String, dynamic> player, bool isRed) onPlayerTap;
  final VoidCallback onGkRedTap;
  final VoidCallback onGkWhiteTap;
  final List<Widget> Function(Map<String, dynamic> stats) eventIconsOf;

  /// Mostra chips (foto) em vez de cartas. Acima de 7 de linha é automático.
  final bool useChips;

  /// Jogador destacado (ex.: toque num evento da timeline).
  final ValueListenable<String?>? highlightedPlayerId;

  /// Altura disponível para o campo; o campo nunca fica menor que o mínimo
  /// necessário para as cartas não se sobreporem.
  final double availableHeight;

  const TacticalPitch({
    super.key,
    required this.teamSize,
    required this.teamRed,
    required this.teamWhite,
    required this.gkRed,
    required this.gkWhite,
    required this.allStats,
    required this.motmPlayerId,
    required this.onPlayerTap,
    required this.onGkRedTap,
    required this.onGkWhiteTap,
    required this.eventIconsOf,
    this.highlightedPlayerId,
    this.availableHeight = 0,
    this.useChips = false,
  });

  @override
  State<TacticalPitch> createState() => _TacticalPitchState();
}

class _TacticalPitchState extends State<TacticalPitch> {
  static const _anim = Duration(milliseconds: 300);

  PitchFocus _focus = PitchFocus.both;
  int _formationIndex = 0;

  // Cache do layout: só recalcula quando tamanho, formato ou foco mudam.
  Size? _cachedSize;
  int? _cachedN;
  int? _cachedFormation;
  bool? _cachedChips;
  PitchFocus? _cachedFocus;
  PitchLayoutResult? _both;
  PitchLayoutResult? _focused;

  void _toggleFocus(PitchFocus tapped) {
    setState(() => _focus = _focus == tapped ? PitchFocus.both : tapped);
  }

  void _resetFocus() {
    if (_focus != PitchFocus.both) setState(() => _focus = PitchFocus.both);
  }

  void _ensureLayout(Size size) {
    if (_cachedSize == size &&
        _cachedN == widget.teamSize &&
        _cachedFormation == _formationIndex &&
        _cachedChips == widget.useChips &&
        _cachedFocus == _focus) {
      return;
    }
    _cachedSize = size;
    _cachedN = widget.teamSize;
    _cachedFormation = _formationIndex;
    _cachedChips = widget.useChips;
    _cachedFocus = _focus;
    _both = PitchLayout.compute(
      lineCount: widget.teamSize,
      field: size,
      formation: _rows,
      chips: widget.useChips,
    );
    _focused = _focus == PitchFocus.both
        ? null
        : PitchLayout.compute(
            lineCount: widget.teamSize,
            field: size,
            focus: _focus,
            formation: _rows,
            chips: widget.useChips,
          );
  }

  List<List<int>> get _presets => formationPresets(widget.teamSize);

  List<int> get _rows {
    final p = _presets;
    return p[_formationIndex < p.length ? _formationIndex : 0];
  }

  /// Altura que ajusta o campo às cartas: usa a maior densidade que cabe na
  /// altura e na largura disponíveis, em vez de esticar o gramado.
  double _fitHeight(double width) {
    final rows = _rows;
    final avail =
        widget.availableHeight > 0 ? widget.availableHeight - 36 : 0.0;
    final order =
        PitchLayout.candidates(widget.teamSize, chips: widget.useChips);
    for (final c in order) {
      final h = PitchLayout.minHeight(widget.teamSize,
          density: c.density, scale: c.scale, formation: rows);
      if (avail > 0 && h > avail) continue;
      final r = PitchLayout.compute(
          lineCount: widget.teamSize,
          field: Size(width, h),
          formation: rows,
          chips: widget.useChips);
      if (r.scale == c.scale) return h;
    }
    final c = order.last;
    final h = PitchLayout.minHeight(widget.teamSize,
        density: c.density, scale: c.scale, formation: rows);
    return h > avail ? h : avail;
  }

  Widget _formationPicker() {
    final presets = _presets;
    if (presets.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final selected = i == _formationIndex;
          return ChoiceChip(
            label: Text(formationRowsLabel(presets[i])),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.textWhite : AppColors.textMuted,
            ),
            selected: selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            selectedColor: AppColors.accentBlue,
            backgroundColor: AppColors.headerBlue,
            side: const BorderSide(color: AppColors.borderSubtle),
            onSelected: (_) => setState(() => _formationIndex = i),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPicker = _presets.length > 1;
    return LayoutBuilder(
      builder: (context, outer) {
        final height = _fitHeight(outer.maxWidth - 20);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [if (hasPicker) _formationPicker(), _pitch(height)],
        );
      },
    );
  }

  Widget _pitch(double height) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      height: height,
      decoration: BoxDecoration(
        color: AppColors.pitchEdge,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _ensureLayout(size);
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: _resetFocus,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _PitchPainter()),
                    ),
                  ),
                  _teamBand(size, isRed: true),
                  _teamBand(size, isRed: false),
                  ..._cards(size),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _teamBand(Size size, {required bool isRed}) {
    final hidden = _focus == (isRed ? PitchFocus.white : PitchFocus.red);
    final color = isRed ? AppColors.redTeam : AppColors.whiteTeam;
    final textColor = isRed ? AppColors.textWhite : AppColors.deepBlue;
    final focused = _focus == (isRed ? PitchFocus.red : PitchFocus.white);
    final top = isRed ? size.height * 0.012 : null;
    final bottom = isRed ? null : size.height * 0.012;
    return Positioned(
      top: top,
      bottom: bottom,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: _anim,
          opacity: hidden ? 0.35 : 1,
          child: GestureDetector(
            onTap: () =>
                _toggleFocus(isRed ? PitchFocus.red : PitchFocus.white),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRed ? 'TIME VERMELHO' : 'TIME BRANCO',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    focused ? Icons.zoom_out_map : Icons.zoom_in,
                    size: 12,
                    color: textColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _cards(Size size) {
    final both = _both!;
    final focused = _focused;
    final widgets = <_Placed>[];

    PitchSlotRect? find(PitchLayoutResult? r, bool isRed, int index) {
      if (r == null) return null;
      for (final s in r.slots) {
        if (s.isRed == isRed && s.index == index) return s;
      }
      return null;
    }

    void add(bool isRed, int index) {
      final hidden = _focus == (isRed ? PitchFocus.white : PitchFocus.red);
      final slot = (hidden
          ? find(both, isRed, index)
          : find(focused ?? both, isRed, index))!;
      final isGk = index < 0;
      final team = isRed ? widget.teamRed : widget.teamWhite;
      final player = isGk
          ? (isRed ? widget.gkRed : widget.gkWhite)
          : (index < team.length ? team[index] : null);
      widgets.add(
        _Placed(
          key: ValueKey('${isRed ? 'r' : 'w'}$index'),
          slot: slot,
          hidden: hidden,
          child: _PitchCard(
            player: player,
            isRed: isRed,
            isGk: isGk,
            density: slot.density,
            stats: player == null
                ? _emptyStats
                : widget.allStats[playerIdFromObject(player)] ?? _emptyStats,
            isMotm:
                player != null &&
                playerIdFromObject(player) == widget.motmPlayerId,
            highlighted: widget.highlightedPlayerId,
            eventIconsOf: widget.eventIconsOf,
            onTap: isGk
                ? (isRed ? widget.onGkRedTap : widget.onGkWhiteTap)
                : () => widget.onPlayerTap(player!, isRed),
            onEmptyTap: isGk
                ? (isRed ? widget.onGkRedTap : widget.onGkWhiteTap)
                : null,
          ),
        ),
      );
    }

    for (final isRed in const [true, false]) {
      add(isRed, -1);
      for (var i = 0; i < widget.teamSize; i++) {
        add(isRed, i);
      }
    }

    // Do fundo para a frente: a carta da frente nunca é encoberta.
    widgets.sort(
      (a, b) => a.slot.rect.center.dy.compareTo(b.slot.rect.center.dy),
    );
    return [
      for (final w in widgets)
        AnimatedPositioned(
          key: w.key,
          duration: _anim,
          curve: Curves.easeOutCubic,
          left: w.slot.itemRect.left,
          top: w.slot.itemRect.top,
          width: w.slot.itemRect.width,
          height: w.slot.itemRect.height,
          child: AnimatedOpacity(
            duration: _anim,
            opacity: w.hidden ? 0.35 : 1,
            child: IgnorePointer(ignoring: w.hidden, child: w.child),
          ),
        ),
    ];
  }
}

class _Placed {
  final Key key;
  final PitchSlotRect slot;
  final bool hidden;
  final Widget child;
  const _Placed({
    required this.key,
    required this.slot,
    required this.hidden,
    required this.child,
  });
}

/// Carta no campo: carta + trilha de eventos/nota logo abaixo, sem sobrepor.
class _PitchCard extends StatefulWidget {
  final Map<String, dynamic>? player;
  final bool isRed;
  final bool isGk;
  final CardDensity density;
  final Map<String, dynamic> stats;
  final bool isMotm;
  final ValueListenable<String?>? highlighted;
  final List<Widget> Function(Map<String, dynamic> stats) eventIconsOf;
  final VoidCallback onTap;
  final VoidCallback? onEmptyTap;

  const _PitchCard({
    required this.player,
    required this.isRed,
    required this.isGk,
    required this.density,
    required this.stats,
    required this.isMotm,
    required this.highlighted,
    required this.eventIconsOf,
    required this.onTap,
    required this.onEmptyTap,
  });

  @override
  State<_PitchCard> createState() => _PitchCardState();
}

class _PitchCardState extends State<_PitchCard> {
  double _scale = 1;

  @override
  void didUpdateWidget(covariant _PitchCard old) {
    super.didUpdateWidget(old);
    final before = (old.stats['goals'] as num?)?.toInt() ?? 0;
    final now = (widget.stats['goals'] as num?)?.toInt() ?? 0;
    if (now > before) _pulse();
  }

  // 1.0 → 1.08 → 1.0 em 250ms, só nesta carta.
  Future<void> _pulse() async {
    setState(() => _scale = 1.08);
    await Future<void>.delayed(const Duration(milliseconds: 125));
    if (mounted) setState(() => _scale = 1);
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return LayoutBuilder(
      builder: (context, c) {
        final cardH = c.maxHeight - PitchLayout.eventTrail;
        return Column(
          children: [
            SizedBox(
              width: c.maxWidth,
              height: cardH,
              child: player == null ? _empty() : _card(player),
            ),
            SizedBox(
              height: PitchLayout.eventTrail,
              child: player == null ? null : _trail(player),
            ),
          ],
        );
      },
    );
  }

  Widget _empty() {
    final color = widget.isGk
        ? (widget.isRed ? AppColors.redTeam : AppColors.whiteTeam)
        : AppColors.textDim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onEmptyTap,
      child: CustomPaint(
        painter: _DashedRRect(color.withValues(alpha: 0.7)),
        child: Center(
          child: widget.isGk
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GK',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.add, size: 14, color: color),
                  ],
                )
              : Icon(
                  Icons.person_outline,
                  size: 20,
                  color: AppColors.textDim.withValues(alpha: 0.3),
                ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> player) {
    final overall = playerOverallOf(player).round();
    final community = player['community'] is CommunityAttributes
        ? player['community'] as CommunityAttributes
        : CommunityAttributes.fromMap(player);
    final teamColor = widget.isRed ? AppColors.redTeam : AppColors.whiteTeam;
    final pid = playerIdFromObject(player);

    Widget card = FittedBox(
      fit: BoxFit.contain,
      child: FifaCard(
        name: player['name']?.toString() ?? '',
        iconPath: player['icon']?.toString(),
        overall: overall,
        attributes: community,
        frame: resolvePlayerFrame(player),
        density: widget.density,
        onTap: widget.onTap,
      ),
    );

    if (widget.highlighted != null) {
      card = ValueListenableBuilder<String?>(
        valueListenable: widget.highlighted!,
        builder: (context, id, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: id == pid
                ? Border.all(color: AppColors.highlightBlue, width: 2)
                : null,
          ),
          child: child,
        ),
        child: card,
      );
    }

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 125),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: card),
            Positioned(
              top: 1,
              left: 1,
              child: widget.isGk
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: AppColors.headerBlue,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.textMuted,
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'GK',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: teamColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.deepBlue, width: 1),
                      ),
                    ),
            ),
            if (widget.isMotm)
              const Positioned(
                top: -6,
                right: -4,
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.goldAccent,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Nota + eventos numa trilha abaixo da carta (máx. 3 ícones, depois "+N").
  Widget _trail(Map<String, dynamic> player) {
    final nota = (widget.stats['nota'] as num?)?.toDouble() ?? 0;
    final icons = widget.eventIconsOf(widget.stats);
    final shown = icons.take(3).toList();
    final extra = icons.length - shown.length;
    if (nota <= 0 && icons.isEmpty) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nota > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.ratingPill(nota),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                nota.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (nota > 0 && shown.isNotEmpty) const SizedBox(width: 3),
          ...shown,
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '+$extra',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  final Color color;
  const _DashedRRect(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRect old) => old.color != color;
}

/// Gramado em perspectiva (trapézio): estreito ao fundo, largo na frente,
/// com a mesma escala de largura que [PitchLayout.widthScale] usa nas cartas.
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Ponto do campo (fx 0..1 na largura, fy 0..1 de fundo a frente).
    Offset pt(double fx, double fy) {
      final ws = PitchLayout.widthScale(fy);
      return Offset(w * (0.5 + (fx - 0.5) * ws), h * fy);
    }

    Path poly(List<Offset> p) => Path()..addPolygon(p, true);

    // Listras alternadas, sutis.
    const stripes = 10;
    for (var i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, h * i / stripes, w, h / stripes + 0.5),
        Paint()
          ..color = i.isEven ? AppColors.pitchStripeA : AppColors.pitchStripeB,
      );
    }

    // Vinheta nas bordas (preto 25%).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            Colors.transparent,
            AppColors.pitchEdge.withValues(alpha: 0.5),
          ],
        ).createShader(rect),
    );

    final line = Paint()
      ..color = AppColors.textWhite.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final soft = Paint()
      ..color = AppColors.textWhite.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const top = 0.03, bottom = 0.97, l = 0.03, r = 0.97;
    canvas.drawPath(
      poly([pt(l, top), pt(r, top), pt(r, bottom), pt(l, bottom)]),
      line,
    );
    canvas.drawLine(pt(l, 0.5), pt(r, 0.5), line);

    // Círculo central (decorativo, 25%): elipse achatada pela perspectiva.
    final c = pt(0.5, 0.5);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w * 0.30, height: h * 0.07),
      soft,
    );

    // Áreas e gols nas duas extremidades.
    for (final back in const [true, false]) {
      double y(double d) => back ? top + d : bottom - d;
      canvas.drawPath(
        poly([
          pt(0.25, y(0)),
          pt(0.75, y(0)),
          pt(0.75, y(0.1)),
          pt(0.25, y(0.1)),
        ]),
        line,
      );
      canvas.drawPath(
        poly([
          pt(0.38, y(0)),
          pt(0.62, y(0)),
          pt(0.62, y(0.04)),
          pt(0.38, y(0.04)),
        ]),
        line,
      );
      final g = back ? top : bottom;
      final dir = back ? -1.0 : 1.0;
      canvas.drawPath(
        poly([
          pt(0.42, g),
          pt(0.42, g + dir * 0.012),
          pt(0.58, g + dir * 0.012),
          pt(0.58, g),
        ]),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => false;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/overall_calculator.dart';
import '../../utils/player_identity.dart';
import '../../utils/rating_calculator.dart';
import '../../utils/tactical_formation.dart';
import '../player/fifa_card.dart';
import '../shared/player_avatar_frame.dart';

/// Campo tático com perspectiva 3D realista, iluminação de estádio,
/// marcações oficiais completas e cartões de jogadores com alta legibilidade.
class TacticalPitch extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final slots = tacticalFormation(teamSize);
    final height = _pitchHeight(teamSize);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF08120B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardW = _cardWidth(constraints.maxWidth, teamSize);
            return Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _PitchPainter())),

                // Indicadores modernos e limpos das equipes
                _endLabel('🔴 TIME VERMELHO', const Alignment(0, -0.98), AppColors.redTeam),
                _endLabel('⚪ TIME BRANCO', const Alignment(0, 0.98), Colors.white),

                // Jogadores de Linha - Vermelho no topo (y < 0)
                ..._teamCards(
                  isRed: true,
                  team: teamRed,
                  slots: slots,
                  cardW: cardW,
                ),

                // Jogadores de Linha - Branco embaixo (y > 0)
                ..._teamCards(
                  isRed: false,
                  team: teamWhite,
                  slots: slots,
                  cardW: cardW,
                ),

                // Goleiro Vermelho (Topo)
                Align(
                  alignment: const Alignment(0, -0.87),
                  child: SizedBox(
                    width: cardW,
                    child: _buildGkCard(gkRed, true, onGkRedTap),
                  ),
                ),

                // Goleiro Branco (Embaixo)
                Align(
                  alignment: const Alignment(0, 0.87),
                  child: SizedBox(
                    width: cardW,
                    child: _buildGkCard(gkWhite, false, onGkWhiteTap),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _endLabel(String text, Alignment align, Color accentColor) {
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: accentColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildGkCard(Map<String, dynamic>? gk, bool isRed, VoidCallback onTap) {
    if (gk == null) {
      return _EmptyPitchGkCard(isRed: isRed, onTap: onTap);
    }
    final pid = playerIdFromObject(gk);
    final stats = allStats[pid] ??
        const {
          'nota': 0.0,
          'goals': 0,
          'assists': 0,
          'ownGoals': 0,
          'yellow': 0,
          'red': 0,
        };
    return _PitchPlayerCard(
      player: gk,
      isRed: isRed,
      stats: stats,
      isMotm: pid == motmPlayerId,
      eventIcons: eventIconsOf(stats),
      onTap: onTap,
    );
  }

  List<Widget> _teamCards({
    required bool isRed,
    required List<Map<String, dynamic>> team,
    required List<FormationSlot> slots,
    required double cardW,
  }) {
    return List<Widget>.generate(slots.length, (i) {
      final player = i < team.length ? team[i] : null;
      final slot = slots[i];
      // Vermelho fica no topo (y vai de -0.58 recuado a -0.16 no meio de campo)
      // Branco fica embaixo (y vai de +0.58 recuado a +0.16 no meio de campo)
      final y = isRed
          ? -0.58 + slot.depth * 0.42
          : 0.58 - slot.depth * 0.42;
      final pid = player == null ? '' : playerIdFromObject(player);
      final stats = allStats[pid] ??
          const {
            'nota': 0.0,
            'goals': 0,
            'assists': 0,
            'ownGoals': 0,
            'yellow': 0,
            'red': 0,
          };
      return Align(
        alignment: Alignment(slot.x * 0.82, y),
        child: SizedBox(
          width: cardW,
          child: player == null
              ? _EmptyPitchCard()
              : _PitchPlayerCard(
                  player: player,
                  isRed: isRed,
                  stats: stats,
                  isMotm: pid == motmPlayerId,
                  eventIcons: eventIconsOf(stats),
                  onTap: () => onPlayerTap(player, isRed),
                ),
        ),
      );
    });
  }

  static double _pitchHeight(int n) {
    if (n <= 3) return 580;
    if (n <= 5) return 660;
    return 720;
  }

  static double _cardWidth(double pitchW, int n) {
    if (n <= 3) return (pitchW * 0.23).clamp(58, 80);
    if (n <= 5) return (pitchW * 0.185).clamp(50, 68);
    return (pitchW * 0.16).clamp(46, 60);
  }
}

class _PitchPlayerCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool isRed;
  final Map<String, dynamic> stats;
  final bool isMotm;
  final List<Widget> eventIcons;
  final VoidCallback onTap;

  const _PitchPlayerCard({
    required this.player,
    required this.isRed,
    required this.stats,
    required this.isMotm,
    required this.eventIcons,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final overall = playerOverallOf(player).round();
    final community = player['community'] is CommunityAttributes
        ? player['community'] as CommunityAttributes
        : CommunityAttributes.fromMap(player);
    final nota = (stats['nota'] as num?)?.toDouble();
    final frame = resolvePlayerFrame(player);
    final teamColor = isRed ? AppColors.redTeam : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Sombra 3D física sob o card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: teamColor.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: FifaCard(
              name: player['name']?.toString() ?? '',
              iconPath: player['icon']?.toString(),
              overall: overall,
              attributes: community,
              frame: frame,
              compact: true,
              onTap: onTap,
            ),
          ),

          // Mini indicador elegante do time no canto superior esquerdo
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: teamColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1),
              ),
            ),
          ),

          // Craque da Partida (MOTM) - Badge refinado
          if (isMotm)
            Positioned(
              top: -8,
              left: -8,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700),
                  size: 14,
                ),
              ),
            ),

          // Ícones de Eventos (Gols, Cartões) em pill escuro
          if (eventIcons.isNotEmpty)
            Positioned(
              top: -6,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 0.8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 3),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: eventIcons),
              ),
            ),

          // Nota do Jogador (estilo SofaScore)
          if (nota != null && nota > 0)
            Positioned(
              bottom: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: getRatingColor(nota),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Text(
                  nota.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyPitchGkCard extends StatelessWidget {
  final bool isRed;
  final VoidCallback onTap;

  const _EmptyPitchGkCard({required this.isRed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isRed ? AppColors.redTeam : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: FifaCard.compactWidth / FifaCard.compactHeight,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.70),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_handball, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                'GK',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                Icons.add_circle_outline,
                color: color.withValues(alpha: 0.75),
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPitchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: FifaCard.compactWidth / FifaCard.compactHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: const Center(
          child: Icon(Icons.person_outline, color: Colors.white24, size: 22),
        ),
      ),
    );
  }
}

/// Pintor customizado do gramado com perspectiva 3D, corte de grama profissional,
/// traves em profundidade e linhas oficiais nítidas.
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Gramado 3D com iluminação central estilo estádio (floodlight radial)
    final turfShader = RadialGradient(
      center: Alignment.center,
      radius: 0.75,
      colors: const [
        Color(0xFF143B23), // Verde esmeralda rico iluminado no meio
        Color(0xFF0F2C1A), // Verde gramado denso
        Color(0xFF08190E), // Borda escura com vinheta de estádio
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = turfShader);

    // 2. Faixas de corte de grama alternadas (mowing stripes)
    const stripeCount = 12;
    final stripeH = size.height / stripeCount;
    final lightStripe = Paint()..color = Colors.white.withValues(alpha: 0.025);
    final darkStripe = Paint()..color = Colors.black.withValues(alpha: 0.06);

    for (var i = 0; i < stripeCount; i++) {
      final sRect = Rect.fromLTWH(0, i * stripeH, size.width, stripeH);
      canvas.drawRect(sRect, i.isEven ? lightStripe : darkStripe);
    }

    // 3. Área de jogo (demarcação do campo com recuo)
    final insetH = 14.0;
    final insetV = 16.0;
    final field = Rect.fromLTWH(
      insetH,
      insetV,
      size.width - insetH * 2,
      size.height - insetV * 2,
    );

    // Efeito de rebaixo do campo (inner drop shadow nas bordas)
    final turfShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(field.inflate(1), const Radius.circular(10)),
      turfShadow,
    );

    // 4. Linhas de campo com giz semi-translúcido nítido
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Linha perimetral com cantos arredondados
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(8)),
      line,
    );

    // Linha do meio de campo
    final midY = size.height / 2;
    canvas.drawLine(Offset(field.left, midY), Offset(field.right, midY), line);

    // Círculo central
    final centerOffset = Offset(size.width / 2, midY);
    final centerRadius = size.width * 0.15;
    canvas.drawCircle(centerOffset, centerRadius, line);

    // Ponto central
    canvas.drawCircle(
      centerOffset,
      3.2,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // 5. Escanteios (Corner arcs nos 4 cantos)
    const cornerR = 10.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(field.left, field.top), radius: cornerR),
      0,
      math.pi / 2,
      false,
      line,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(field.right, field.top), radius: cornerR),
      math.pi / 2,
      math.pi / 2,
      false,
      line,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(field.right, field.bottom), radius: cornerR),
      math.pi,
      math.pi / 2,
      false,
      line,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(field.left, field.bottom), radius: cornerR),
      3 * math.pi / 2,
      math.pi / 2,
      false,
      line,
    );

    // 6. Áreas de pênalti e gol nos dois lados (Grande Área, Pequena Área, Meia-lua e Pênalti)
    _drawPenaltyArea(canvas, field, line, isTop: true);
    _drawPenaltyArea(canvas, field, line, isTop: false);

    // 7. Traves em 3D com profundidade de rede atrás da linha de gol
    _draw3DGoal(canvas, field, isTop: true);
    _draw3DGoal(canvas, field, isTop: false);

    // 8. Iluminação suave de zona das equipes
    final teamAmbient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.redTeam.withValues(alpha: 0.05),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, teamAmbient);
  }

  void _drawPenaltyArea(Canvas canvas, Rect field, Paint line, {required bool isTop}) {
    // Grande Área
    final bigBoxW = field.width * 0.50;
    final bigBoxH = field.height * 0.125;
    final bigBoxLeft = field.center.dx - bigBoxW / 2;
    final bigBoxTop = isTop ? field.top : field.bottom - bigBoxH;
    canvas.drawRect(Rect.fromLTWH(bigBoxLeft, bigBoxTop, bigBoxW, bigBoxH), line);

    // Pequena Área (Área de Meta)
    final smallBoxW = field.width * 0.26;
    final smallBoxH = field.height * 0.052;
    final smallBoxLeft = field.center.dx - smallBoxW / 2;
    final smallBoxTop = isTop ? field.top : field.bottom - smallBoxH;
    canvas.drawRect(Rect.fromLTWH(smallBoxLeft, smallBoxTop, smallBoxW, smallBoxH), line);

    // Marca do Pênalti
    final penaltySpotY = isTop ? field.top + bigBoxH * 0.72 : field.bottom - bigBoxH * 0.72;
    canvas.drawCircle(
      Offset(field.center.dx, penaltySpotY),
      2.6,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Meia-lua da Grande Área (D-box)
    final arcRadius = field.width * 0.14;
    final arcCenter = Offset(field.center.dx, penaltySpotY);
    if (isTop) {
      canvas.drawArc(
        Rect.fromCircle(center: arcCenter, radius: arcRadius),
        0.65,
        1.84,
        false,
        line,
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: arcCenter, radius: arcRadius),
        math.pi + 0.65,
        1.84,
        false,
        line,
      );
    }
  }

  void _draw3DGoal(Canvas canvas, Rect field, {required bool isTop}) {
    final goalW = field.width * 0.20;
    final goalH = 8.0;
    final gLeft = field.center.dx - goalW / 2;
    final gTop = isTop ? field.top - goalH : field.bottom;

    // Fundo sombreado da rede (profundidade)
    final netPocket = Rect.fromLTWH(gLeft, gTop, goalW, goalH);
    canvas.drawRect(
      netPocket,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Malha sutil da rede
    final netGrid = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..strokeWidth = 0.8;
    for (var x = gLeft + 4; x < gLeft + goalW; x += 6) {
      canvas.drawLine(Offset(x, gTop), Offset(x, gTop + goalH), netGrid);
    }

    // Traves e travessão branco sólido em 3D
    final postPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(netPocket, postPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

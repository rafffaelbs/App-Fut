import 'package:flutter/material.dart';
import '../../utils/overall_calculator.dart';
import '../shared/player_avatar_frame.dart';

/// Card de jogador no estilo FIFA/Ultimate Team.
///
/// - Overall em destaque (canto superior esquerdo)
/// - Ícone do jogador preservado (asset escolhido no perfil)
/// - Nome e os 6 atributos (PAC SHO PAS / DRI DEF PHY)
/// - Cor do card muda por faixa: bronze < 65, prata 65-74, ouro 75-84, elite 85+
///
/// O card é desenhado num espaço fixo e escalado com [FittedBox], então
/// funciona igual no grid do Elenco, no perfil e (em [compact]) no campo tático.
class FifaCard extends StatelessWidget {
  static const double designWidth = 200;
  static const double designHeight = 290;
  static const double compactWidth = 132;
  static const double compactHeight = 168;

  final String name;
  final String? iconPath;
  final int overall;
  final CommunityAttributes? attributes;
  final PlayerFrameInfo? frame;

  /// Versão enxuta (overall + ícone + nome) para o campo tático.
  final bool compact;

  /// Toque no card inteiro (ex.: abrir o perfil).
  final VoidCallback? onTap;

  /// Toque só no ícone (ex.: trocar o ícone no perfil). Quando informado,
  /// mostra um pequeno lápis sobre o ícone.
  final VoidCallback? onIconTap;

  /// Quando informado, mostra o botão "x" no canto (use só para admins).
  final VoidCallback? onRemove;

  const FifaCard({
    super.key,
    required this.name,
    required this.overall,
    this.iconPath,
    this.attributes,
    this.frame,
    this.compact = false,
    this.onTap,
    this.onIconTap,
    this.onRemove,
  });

  double get _w => compact ? compactWidth : designWidth;
  double get _h => compact ? compactHeight : designHeight;

  @override
  Widget build(BuildContext context) {
    final tier = cardTierFor(overall);
    final palette = cardPaletteFor(tier);
    final hasFrame = frame != null && frame!.type != PlayerFrameType.none;

    Widget card = SizedBox(
      width: _w,
      height: _h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: FifaShieldPainter(palette, frame: frame),
              ),
            ),
            _buildOverall(palette, tier),
            _buildIcon(palette),
            _buildName(palette),
            if (!compact) _buildAttributes(palette),
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            // Mini badge de frame (coroa, estrelas, chama) sobre o ícone
            if (hasFrame) _buildFrameBadge(),
          ],
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: _w / _h,
      child: FittedBox(fit: BoxFit.contain, child: card),
    );
  }

  /// Mini badge posicionado no topo do card (coroa para Bola de Ouro,
  /// estrelas para Craque do Mês, chama para Artilheiro).
  Widget _buildFrameBadge() {
    if (frame == null || frame!.type == PlayerFrameType.none) {
      return const SizedBox.shrink();
    }
    final badgeTop = compact ? 4.0 : 6.0;
    final iconSize = compact ? 11.0 : 16.0;

    Widget? badgeChild;
    Color badgeColor;

    switch (frame!.type) {
      case PlayerFrameType.bolaDeOuro:
        badgeColor = const Color(0xFFFFD700);
        badgeChild = Icon(Icons.military_tech_rounded, color: badgeColor, size: iconSize);
        break;
      case PlayerFrameType.craqueDoMes:
        badgeColor = const Color(0xFF00E5FF);
        final count = frame!.count;
        if (count <= 3) {
          badgeChild = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < count; i++)
                Icon(Icons.star_rounded, color: const Color(0xFFFFD700), size: iconSize * 0.85),
            ],
          );
        } else {
          badgeChild = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count', style: TextStyle(color: const Color(0xFFFFD700), fontSize: iconSize * 0.85, fontWeight: FontWeight.w900, height: 1)),
              Icon(Icons.star_rounded, color: const Color(0xFFFFD700), size: iconSize * 0.85),
            ],
          );
        }
        break;
      case PlayerFrameType.artilheiro:
        badgeColor = const Color(0xFFFF6D00);
        badgeChild = Icon(Icons.local_fire_department_rounded, color: badgeColor, size: iconSize);
        break;
      case PlayerFrameType.diamond:
        badgeColor = const Color(0xFF00E5FF);
        badgeChild = Icon(Icons.diamond_rounded, color: badgeColor, size: iconSize);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Positioned(
      top: badgeTop,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: badgeColor.withValues(alpha: 0.7), width: 1),
          ),
          child: badgeChild,
        ),
      ),
    );
  }

  Widget _buildOverall(CardPalette p, CardTier tier) {
    return Positioned(
      left: compact ? 10 : 22,
      top: compact ? 18 : 34,
      width: compact ? 42 : 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$overall',
            style: TextStyle(
              color: p.text,
              fontSize: compact ? 28 : 44,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'OVR',
            style: TextStyle(
              color: p.text,
              fontSize: compact ? 9 : 13,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: 1,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Container(width: 30, height: 1.5, color: p.text.withValues(alpha: 0.35)),
            const SizedBox(height: 6),
            Text(
              cardTierLabel(tier).toUpperCase(),
              style: TextStyle(
                color: p.text.withValues(alpha: 0.75),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon(CardPalette p) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Widget fallback() => Center(
          child: Text(
            initial,
            style: TextStyle(
              color: p.text,
              fontSize: 56,
              fontWeight: FontWeight.w900,
            ),
          ),
        );

    final Widget image = (iconPath != null && iconPath!.isNotEmpty)
        ? Image.asset(
            iconPath!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallback(),
          )
        : fallback();

    return Positioned(
      left: compact ? 50 : 84,
      top: compact ? 22 : 34,
      width: compact ? 74 : 96,
      height: compact ? 76 : 100,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onIconTap ?? onTap,
        child: Stack(
          children: [
            Positioned.fill(child: image),
            if (onIconTap != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildName(CardPalette p) {
    return Positioned(
      left: compact ? 6 : 14,
      right: compact ? 6 : 14,
      top: compact ? 104 : 146,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 2,
              vertical: compact ? 1.5 : 0,
            ),
            decoration: compact
                ? BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.text,
                fontSize: compact ? 14 : 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                height: 1.1,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Container(height: 1.5, color: p.text.withValues(alpha: 0.3)),
          ],
        ],
      ),
    );
  }

  Widget _buildAttributes(CardPalette p) {
    Widget row(String key) {
      final v = attributes?.valueOf(key);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                v?.toString() ?? '–',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: p.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 32,
              child: Text(
                kAttributeLabels[key]!,
                style: TextStyle(
                  color: p.text.withValues(alpha: 0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Positioned(
      left: 16,
      right: 16,
      top: 164,
      child: Row(
        children: [
          Expanded(
            child: Column(children: [row('pac'), row('sho'), row('pas')]),
          ),
          Container(
            width: 1.5,
            height: 68,
            color: p.text.withValues(alpha: 0.3),
          ),
          Expanded(
            child: Column(children: [row('dri'), row('def'), row('phy')]),
          ),
        ],
      ),
    );
  }
}

Path fifaShieldPath(Size s) {
  final w = s.width, h = s.height;
  return Path()
    ..moveTo(0, 26)
    ..quadraticBezierTo(0, 0, 26, 0)
    ..lineTo(w - 26, 0)
    ..quadraticBezierTo(w, 0, w, 26)
    ..lineTo(w, h - 64)
    ..cubicTo(w, h - 26, w * 0.72, h - 10, w / 2, h)
    ..cubicTo(w * 0.28, h - 10, 0, h - 26, 0, h - 64)
    ..close();
}

class FifaShieldPainter extends CustomPainter {
  final CardPalette palette;
  final PlayerFrameInfo? frame;
  FifaShieldPainter(this.palette, {this.frame});

  /// Retorna as cores do gradiente de moldura para cada tipo de frame.
  List<Color>? _frameColors() {
    if (frame == null || frame!.type == PlayerFrameType.none) return null;
    switch (frame!.type) {
      case PlayerFrameType.bolaDeOuro:
        return const [Color(0xFFFFF9A6), Color(0xFFFFD700), Color(0xFFFFA000), Color(0xFFFFD700)];
      case PlayerFrameType.craqueDoMes:
        return const [Color(0xFF00E5FF), Color(0xFF00B0FF), Color(0xFFFFD700), Color(0xFF00E5FF)];
      case PlayerFrameType.artilheiro:
        return const [Color(0xFFFFEA00), Color(0xFFFF5722), Color(0xFFD50000), Color(0xFFFF9100)];
      case PlayerFrameType.gold:
        return const [Color(0xFFFFF59D), Color(0xFFFFD700), Color(0xFFFFAB00), Color(0xFFFFD700)];
      case PlayerFrameType.silver:
        return const [Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFFB0BEC5), Color(0xFFECEFF1)];
      case PlayerFrameType.bronze:
        return const [Color(0xFFFFB74D), Color(0xFFCD7F32), Color(0xFF8D6E63), Color(0xFFD7CCC8)];
      case PlayerFrameType.diamond:
        return const [Color(0xFFE2F1F8), Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF7DD3FC)];
      case PlayerFrameType.none:
        return null;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = fifaShieldPath(size);

    canvas.drawShadow(path, Colors.black, 6, true);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: palette.gradient,
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);

    // Brilho suave no topo
    final shine = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, shine);

    // Moldura metálica de prestígio (quando o jogador tem frame)
    final frameColors = _frameColors();
    if (frameColors != null) {
      // Borda metálica externa nítida e refinada (sem blur/neon)
      final framePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: frameColors,
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, framePaint);

      // Traço interno metálico com chanfro sutil para efeito 3D
      final framePaintInner = Paint()
        ..color = frameColors[0].withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round;
      canvas.save();
      canvas.translate(size.width * 0.015, size.height * 0.01);
      canvas.scale(0.97, 0.98);
      canvas.drawPath(fifaShieldPath(size), framePaintInner);
      canvas.restore();
    } else {
      // Borda interna padrão (sem frame)
      final inner = Path()
        ..addPath(path, Offset.zero)
        ..close();
      canvas.save();
      canvas.translate(size.width * 0.03, size.height * 0.02);
      canvas.scale(0.94, 0.96);
      canvas.drawPath(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = palette.text.withValues(alpha: 0.35),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FifaShieldPainter old) =>
      old.palette != palette || old.frame != frame;
}

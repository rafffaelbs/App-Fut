import 'package:flutter/material.dart';

import '../../utils/cosmetic_resolver.dart';

/// Contorno cosmético desenhado fora do filho, separado por um [gap].
/// Redondo por padrão; com [borderRadius] vira retângulo arredondado.
/// Sem moldura no [cosmetic], devolve o filho intacto.
class CosmeticFrame extends StatelessWidget {
  final Widget child;
  final ResolvedCosmetic cosmetic;
  final double thickness;
  final double gap;
  final double? borderRadius;

  /// Contorno customizado (ex.: escudo da carta); tem prioridade sobre
  /// [borderRadius]. Recebe o tamanho do retângulo a contornar.
  final Path Function(Size size)? pathBuilder;

  /// Glow só onde permitido (carta cheia, pódio); nunca em campo e listas.
  final bool glow;

  /// Linha interna safira quando há Craque do Mês + outra moldura.
  final bool allowDouble;

  const CosmeticFrame({
    super.key,
    required this.child,
    required this.cosmetic,
    this.thickness = 1.5,
    this.gap = 2,
    this.borderRadius,
    this.pathBuilder,
    this.glow = false,
    this.allowDouble = true,
  });

  @override
  Widget build(BuildContext context) {
    final frame = cosmetic.frame;
    if (frame == null) return child;

    final inner = allowDouble && frame.isDouble;
    final innerExtra = inner ? 2.0 : 0.0; // gap de 1dp + linha de 1dp
    final pad = thickness + gap + innerExtra;

    return CustomPaint(
      painter: _FramePainter(
        colors: frame.colors,
        innerColor: inner ? frame.innerColor : null,
        thickness: thickness,
        radius: borderRadius,
        pathBuilder: pathBuilder,
        glow: glow && cosmetic.allowsGlow,
      ),
      child: Padding(padding: EdgeInsets.all(pad), child: child),
    );
  }
}

class _FramePainter extends CustomPainter {
  final List<Color> colors;
  final Color? innerColor;
  final double thickness;
  final double? radius;
  final Path Function(Size size)? pathBuilder;
  final bool glow;

  _FramePainter({
    required this.colors,
    required this.innerColor,
    required this.thickness,
    required this.radius,
    required this.pathBuilder,
    required this.glow,
  });

  void _draw(Canvas canvas, Rect rect, Paint paint) {
    if (pathBuilder != null) {
      canvas.drawPath(pathBuilder!(rect.size).shift(rect.topLeft), paint);
    } else if (radius == null) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius!)), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = (Offset.zero & size).deflate(thickness / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..isAntiAlias = true;
    if (colors.length > 1) {
      stroke.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Offset.zero & size);
    } else {
      stroke.color = colors.first;
    }

    if (glow) {
      // Glow contido: blur <= 8dp, opacidade <= 35%.
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = colors.first.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      _draw(canvas, outer, glowPaint);
    }
    _draw(canvas, outer, stroke);

    if (innerColor != null) {
      final innerRect = (Offset.zero & size).deflate(thickness + 1.5);
      _draw(
        canvas,
        innerRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = innerColor!,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.colors != colors ||
      old.innerColor != innerColor ||
      old.thickness != thickness ||
      old.radius != radius ||
      old.pathBuilder != pathBuilder ||
      old.glow != glow;
}

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/cosmetic_resolver.dart';
import '../../utils/overall_calculator.dart';
import '../shared/cosmetic_frame.dart';
import '../shared/cosmetic_name.dart';
import '../shared/player_avatar_frame.dart';
import '../shared/stars_badge.dart';

/// Densidades da carta (docs/design/06 e 03 §4.4).
///
/// - [full]: Elenco/perfil/peek — atributos, glow permitido.
/// - [large] (L): campo, espaço folgado.
/// - [medium] (M): campo, futsal 5×5 em retrato.
/// - [small] (S): chip (foto circular), campo 7×7 / 11×11.
enum CardDensity { full, large, medium, small }

/// Medidas de cada densidade, em dp de desenho (a carta é escalada por
/// [FittedBox], então vale igual em qualquer tamanho).
class _Metrics {
  final double w, h;
  static const frameGap = 2.0;
  final double frameThickness;
  final bool doubleFrame, texture, glow;
  const _Metrics({
    required this.w,
    required this.h,
    required this.frameThickness,
    required this.doubleFrame,
    required this.texture,
    required this.glow,
  });

  /// Espaço que a moldura cosmética ocupa ao redor da carta.
  double framePad(bool hasDouble) =>
      frameThickness + frameGap + (doubleFrame && hasDouble ? 2 : 0);
}

const _metrics = {
  CardDensity.full: _Metrics(
      w: 200, h: 280, frameThickness: 1.5, doubleFrame: true,
      texture: true, glow: true),
  CardDensity.large: _Metrics(
      w: 132, h: 168, frameThickness: 1.5, doubleFrame: true,
      texture: true, glow: false),
  CardDensity.medium: _Metrics(
      w: 60, h: 84, frameThickness: 1, doubleFrame: false,
      texture: true, glow: false),
  CardDensity.small: _Metrics(
      w: 64, h: 84, frameThickness: 1.5, doubleFrame: false,
      texture: false, glow: false),
};

/// Card de jogador no estilo FIFA/Ultimate Team, em camadas:
/// escudo (tier) → textura → foto → textos → divisória + atributos →
/// moldura cosmética (fora do escudo) → estrelas.
///
/// Faixas do tier: ver `tierForOverall` (bronze, prata, ouro, platina, lendária).
/// Cosméticos vêm sempre de [frame] (`resolveCosmetic`).
class FifaCard extends StatelessWidget {
  static const double designWidth = 200;
  static const double designHeight = 280;
  static const double compactWidth = 132;
  static const double compactHeight = 168;

  /// Textura swirl (máscara tingida pela cor do tier), na carta toda.
  static const patternAsset = 'assets/card_patterns/swirl.png';

  /// Mesmo provider em todas as cartas, para decodificar o PNG uma vez.
  static const ImageProvider patternImage =
      ResizeImage(AssetImage(patternAsset), width: 240);

  /// Chame uma vez com contexto montado (ex.: ao abrir o Elenco/Partida).
  static Future<void> precache(BuildContext context) =>
      precacheImage(patternImage, context);

  final String name;
  final String? iconPath;
  final int overall;
  final CommunityAttributes? attributes;
  final PlayerFrameInfo? frame;
  final CardDensity density;

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
    this.density = CardDensity.full,
    this.onTap,
    this.onIconTap,
    this.onRemove,
  });

  _Metrics get _m => _metrics[density]!;

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final tier = tierForOverall(overall);
    final palette = cardPaletteFor(tier);
    final cosmetic = (frame ?? PlayerFrameInfo.none).cosmetic;
    final hasFrame = cosmetic.frame != null;

    final Widget body = density == CardDensity.small
        ? _SmallChip(
            name: name,
            iconPath: iconPath,
            overall: overall,
            palette: palette,
            cosmetic: cosmetic,
          )
        : _buildShieldCard(m, tier, palette, cosmetic);

    double outerW = m.w, outerH = m.h;
    Widget card = body;
    if (density != CardDensity.small && hasFrame) {
      final pad = m.framePad(cosmetic.frame!.isDouble);
      outerW += pad * 2;
      outerH += pad * 2;
      card = CosmeticFrame(
        cosmetic: cosmetic,
        thickness: m.frameThickness,
        gap: _Metrics.frameGap,
        pathBuilder: fifaShieldPath,
        glow: m.glow,
        allowDouble: m.doubleFrame,
        child: body,
      );
    }

    card = SizedBox(
      width: outerW,
      height: outerH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: card),
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
                      color: AppColors.cosmeticNamePlate,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textWhite),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Com restrição limitada a carta escala para caber; sem restrição
    // (ex.: dentro de um FittedBox) usa o tamanho natural. AspectRatio sem
    // limite não tem tamanho e a carta sumia.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, c) {
          if (!c.hasBoundedWidth && !c.hasBoundedHeight) return card;
          return AspectRatio(
            aspectRatio: outerW / outerH,
            child: FittedBox(fit: BoxFit.contain, child: card),
          );
        },
      ),
    );
  }

  // ── Carta com escudo (full / L / M) ────────────────────────────────

  Widget _buildShieldCard(
      _Metrics m, CardTier tier, CardPalette p, ResolvedCosmetic cosmetic) {
    final full = density == CardDensity.full;
    final large = density == CardDensity.large;
    final medium = density == CardDensity.medium;

    // Retângulo da foto (e da textura atrás dela).
    final Rect photo = full
        ? const Rect.fromLTWH(78, 20, 108, 116)
        : large
            ? const Rect.fromLTWH(40, 16, 72, 80)
            : const Rect.fromLTWH(24, 6, 34, 40);
    final double nameTop = full ? 142 : (large ? 100 : 52);
    final double nameH = full ? 24 : (large ? 18 : 14);
    final double nameFont = full ? 20 : (large ? 14 : 10);
    final double sideInset = full ? 14 : (large ? 8 : 3);

    final starsCompact = !full && !large || cosmetic.stars > 3;

    Widget nameText = CosmeticName(
      name: full || large ? name.toUpperCase() : _shortName(name),
      cosmetic: cosmetic,
      solid: medium,
      plaque: true,
      compactPlaque: medium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTheme.number(
        fontSize: nameFont,
        fontWeight: FontWeight.w700,
        color: p.nameText,
      ).copyWith(letterSpacing: 0.4, height: 1.1),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1–2. Escudo + gradiente do tier
        Positioned.fill(
          child: CustomPaint(painter: FifaShieldPainter(p)),
        ),
        // 3. Swirl uniforme na carta toda (recortado pelo escudo)
        if (m.texture)
          Positioned.fill(
            child: ClipPath(
              clipper: const _ShieldClipper(),
              child: _CardPattern(color: p.pattern, opacity: _patternOpacity),
            ),
          ),
        // 4. Foto
        Positioned.fromRect(
          rect: photo,
          child: _PlayerPhoto(
            name: name,
            iconPath: iconPath,
            color: p.text,
            fontSize: full ? 56 : 28,
            onTap: onIconTap ?? onTap,
            showEdit: onIconTap != null,
          ),
        ),
        // 5. OVR (Z1) + estrelas
        Positioned(
          left: full ? 18 : (large ? 8 : 2),
          top: full ? 30 : (large ? 16 : 6),
          width: full ? 56 : (large ? 34 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$overall',
                style: AppTheme.number(
                  fontSize: full ? 40 : (large ? 26 : 14),
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ).copyWith(height: 1),
              ),
              if (full || large) ...[
                const SizedBox(height: 2),
                Text(
                  cardTierLabel(tier).toUpperCase(),
                  style: TextStyle(
                    color: p.text.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    height: 1,
                  ),
                ),
              ],
              if (cosmetic.stars > 0) ...[
                SizedBox(height: full ? 6 : 2),
                StarsBadge(
                  stars: cosmetic.stars,
                  compact: starsCompact,
                  size: full ? 14 : 10,
                ),
              ],
            ],
          ),
        ),
        // 5. Nome (Z4) — sem sombra
        Positioned(
          left: sideInset,
          right: sideInset,
          top: nameTop,
          height: nameH,
          child: Center(child: nameText),
        ),
        // 6. Divisória + atributos (só carta cheia)
        if (full) _buildAttributes(p, nameTop + nameH),
      ],
    );
  }

  /// Caracteres do nome na carta M (campo).
  static const _mediumNameChars = 12;

  static String _shortName(String n) {
    final t = n.trim().toUpperCase();
    return t.length <= _mediumNameChars ? t : t.substring(0, _mediumNameChars);
  }

  /// Linha divisória e atributos **abaixo** dela. A distância base do nome →
  /// linha é igual à da linha → topo dos atributos (4% da altura).
  Widget _buildAttributes(CardPalette p, double nameBottom) {
    final gap = designHeight * 0.04;
    const rowH = 20.0;

    Widget row(String key) {
      final v = attributes?.valueOf(key);
      return SizedBox(
        height: rowH,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                v?.toString() ?? '—',
                textAlign: TextAlign.right,
                style: AppTheme.number(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: p.nameText,
                ).copyWith(height: 1.1),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 34,
              child: Text(
                kAttributeLabels[key]!,
                style: TextStyle(
                  color: p.nameText.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final lineColor = p.nameText.withValues(alpha: 0.3);
    return Positioned(
      left: 20,
      right: 20,
      top: nameBottom + gap,
      child: Column(
        children: [
          Container(key: const ValueKey('card-divider'), height: 1.5, color: lineColor),
          SizedBox(
            key: const ValueKey('card-attrs'),
            height: gap + rowH * 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: gap),
                    child: Column(children: [row('pac'), row('sho'), row('pas')]),
                  ),
                ),
                Container(width: 1.5, color: lineColor),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: gap),
                    child: Column(children: [row('dri'), row('def'), row('phy')]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto do jogador (PNG transparente) com fallback para a inicial.
class _PlayerPhoto extends StatelessWidget {
  final String name;
  final String? iconPath;
  final Color color;
  final double fontSize;
  final VoidCallback? onTap;
  final bool showEdit;

  const _PlayerPhoto({
    required this.name,
    required this.iconPath,
    required this.color,
    required this.fontSize,
    required this.onTap,
    required this.showEdit,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    Widget fallback() => Center(
          child: Text(initial,
              style: AppTheme.number(
                  fontSize: fontSize, fontWeight: FontWeight.w700, color: color)),
        );

    final Widget image = (iconPath != null && iconPath!.isNotEmpty)
        ? Image.asset(iconPath!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback())
        : fallback();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(child: image),
          if (showEdit)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.cosmeticNamePlate,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 11, color: AppColors.textWhite),
              ),
            ),
        ],
      ),
    );
  }
}

/// Intensidade do swirl, igual na carta toda (a mais fraca da spec, 10–18%,
/// para o texto manter contraste).
const double _patternOpacity = 0.14;

class _ShieldClipper extends CustomClipper<Path> {
  const _ShieldClipper();
  @override
  Path getClip(Size size) => fifaShieldPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Textura ondulada (`swirl.png`) em tons do tier.
///
/// O PNG vira máscara de luminância e é mapeado (gradient map) entre o tier
/// a −25% e +20% de luminosidade; a opacidade vai embutida na matriz para
/// custar uma única camada.
class _CardPattern extends StatelessWidget {
  final Color color;
  final double opacity;
  const _CardPattern({required this.color, required this.opacity});

  static ColorFilter _filterFor(Color tier, double opacity) {
    final dark = shiftLightness(tier, -0.25);
    final light = shiftLightness(tier, 0.20);
    List<double> row(double d, double l) {
      final k = l - d;
      return [k * 0.2126, k * 0.7152, k * 0.0722, 0, d * 255];
    }

    return ColorFilter.matrix([
      ...row(dark.r, light.r),
      ...row(dark.g, light.g),
      ...row(dark.b, light.b),
      0, 0, 0, opacity, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColorFiltered(
        colorFilter: _filterFor(color, opacity),
        child: Image(
          image: FifaCard.patternImage,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Densidade S: chip com foto circular, OVR em badge, nome 12sp.
class _SmallChip extends StatelessWidget {
  final String name;
  final String? iconPath;
  final int overall;
  final CardPalette palette;
  final ResolvedCosmetic cosmetic;

  const _SmallChip({
    required this.name,
    required this.iconPath,
    required this.overall,
    required this.palette,
    required this.cosmetic,
  });

  @override
  Widget build(BuildContext context) {
    final short = name.trim().toUpperCase();
    final shortName = short.length <= 10 ? short : short.substring(0, 10);

    final Widget photo = CosmeticFrame(
      cosmetic: cosmetic,
      thickness: 1.5,
      gap: 1,
      allowDouble: false,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette.gradient,
          ),
          border: palette.border == null
              ? null
              : Border.all(color: palette.border!, width: 1.5),
        ),
        child: ClipOval(
          child: _PlayerPhoto(
            name: name,
            iconPath: iconPath,
            color: palette.text,
            fontSize: 22,
            onTap: null,
            showEdit: false,
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(top: 0, left: 9, child: photo),
        // OVR em badge
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
            decoration: BoxDecoration(
              color: palette.gradient[1],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.cosmeticNamePlate, width: 1),
            ),
            child: Text('$overall',
                style: AppTheme.number(
                        fontSize: 12, fontWeight: FontWeight.w700, color: palette.text)
                    .copyWith(height: 1)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 50,
          child: CosmeticName(
            name: shortName,
            cosmetic: cosmetic,
            solid: true,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: AppTheme.number(fontSize: 12, fontWeight: FontWeight.w700)
                .copyWith(height: 1.15),
          ),
        ),
        if (cosmetic.stars > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 67,
            child: Center(
                child: StarsBadge(stars: cosmetic.stars, compact: true, size: 11)),
          ),
      ],
    );
  }
}

/// Escudo da carta; escala com a largura (desenhado para 200dp).
Path fifaShieldPath(Size s) {
  final w = s.width, h = s.height;
  final k = w / 200;
  final r = 26 * k, tail = 64 * k;
  return Path()
    ..moveTo(0, r)
    ..quadraticBezierTo(0, 0, r, 0)
    ..lineTo(w - r, 0)
    ..quadraticBezierTo(w, 0, w, r)
    ..lineTo(w, h - tail)
    ..cubicTo(w, h - 26 * k, w * 0.72, h - 10 * k, w / 2, h)
    ..cubicTo(w * 0.28, h - 10 * k, 0, h - 26 * k, 0, h - tail)
    ..close();
}

/// Escudo + gradiente do tier (+ borda de 3dp na Platina). A moldura
/// cosmética **não** é desenhada aqui: fica fora do escudo (`CosmeticFrame`).
class FifaShieldPainter extends CustomPainter {
  final CardPalette palette;
  FifaShieldPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final path = fifaShieldPath(size);
    final rect = Offset.zero & size;

    canvas.drawShadow(path, AppColors.cardShadow, 4, true);

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.gradient,
        ).createShader(rect),
    );

    final border = palette.border;
    final innerLine = palette.innerLine;
    if (innerLine != null) {
      // Lendária: linha interna de 2dp (traço de 4dp recortado para dentro).
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (size.width / 200).clamp(0.5, 1.0)
          ..strokeJoin = StrokeJoin.round
          ..color = innerLine,
      );
      canvas.restore();
    } else if (border != null) {
      // Borda integrada ao escudo: traço de 6dp recortado para dentro = 3dp.
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (size.width / 200).clamp(0.5, 1.0)
          ..strokeJoin = StrokeJoin.round
          ..color = border,
      );
      canvas.restore();
    } else {
      // Filete interno sutil nos demais tiers.
      canvas.save();
      canvas.translate(size.width * 0.03, size.height * 0.02);
      canvas.scale(0.94, 0.96);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = palette.text.withValues(alpha: 0.30),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FifaShieldPainter old) => old.palette != palette;
}

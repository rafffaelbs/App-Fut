import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../utils/cosmetic_resolver.dart';
import 'cosmetic_frame.dart';
import 'cosmetic_icon.dart';
import 'stars_badge.dart';

/// Origem da moldura (para telas que ainda ramificam por tipo, ex.: `fifa_card`).
enum PlayerFrameType { none, bolaDeOuro, craqueDoMes, artilheiro, bronze, silver, gold, diamond }

/// Cosméticos resolvidos de um jogador, no formato consumido pelas telas.
class PlayerFrameInfo {
  final ResolvedCosmetic cosmetic;
  const PlayerFrameInfo(this.cosmetic);

  static final PlayerFrameInfo none =
      PlayerFrameInfo(resolveCosmetic(PlayerCosmetics.none));

  /// Estrelas do Craque do Mês.
  int get count => cosmetic.stars;

  /// Tipo da moldura principal, segundo a precedência do resolver.
  PlayerFrameType get type {
    switch (cosmetic.frameSource) {
      case FrameSource.none:
        return PlayerFrameType.none;
      case FrameSource.goldenBall:
        return PlayerFrameType.bolaDeOuro;
      case FrameSource.monthly:
        return PlayerFrameType.craqueDoMes;
      case FrameSource.nameEffect:
        return switch (cosmetic.source.nameEffect.name) {
          'fire' => PlayerFrameType.artilheiro,
          'diamond' => PlayerFrameType.diamond,
          'gold' => PlayerFrameType.gold,
          'silver' => PlayerFrameType.silver,
          _ => PlayerFrameType.bronze,
        };
    }
  }
}

/// Resolve os cosméticos de um mapa de jogador (com fallback legado).
PlayerFrameInfo resolvePlayerFrame(Map<String, dynamic> player) =>
    PlayerFrameInfo(resolveCosmetic(PlayerCosmetics.fromMap(player)));

/// Avatar com moldura, ícone principal e estrelas, tudo vindo do resolver.
/// Sem glow: usado em listas e campo. Para pódio/carta, use [CosmeticFrame]
/// com `glow: true`.
class PlayerAvatarFrame extends StatelessWidget {
  final Widget child;
  final PlayerFrameInfo frame;
  final bool compact;
  final bool isCircular;
  final bool glow;

  const PlayerAvatarFrame({
    super.key,
    required this.child,
    required this.frame,
    this.compact = false,
    this.isCircular = true,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = frame.cosmetic;
    if (c.frame == null && c.stars == 0) return child;

    final iconSize = compact ? 12.0 : 16.0;
    final icon = c.primaryIcon;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        CosmeticFrame(
          cosmetic: c,
          thickness: isCircular ? 2 : 1.5,
          gap: isCircular ? 1 : 2,
          borderRadius: isCircular ? null : 10,
          glow: glow,
          allowDouble: !compact,
          child: child,
        ),
        if (icon != null)
          Positioned(
            top: -iconSize / 3,
            right: -iconSize / 3,
            child: _Badge(child: CosmeticIcon(spec: icon, size: iconSize)),
          ),
        if (c.stars > 0)
          Positioned(
            bottom: -iconSize / 2,
            child: _Badge(
              child: StarsBadge(stars: c.stars, compact: compact, size: compact ? 10 : 12),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cosmeticNamePlate,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(padding: const EdgeInsets.all(1), child: child),
      );
}

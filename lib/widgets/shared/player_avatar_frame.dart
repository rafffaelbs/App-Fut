import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Tipos de molduras disponíveis para os jogadores.
enum PlayerFrameType {
  none,
  bolaDeOuro,   // 👑 Exclusivo: Coroa real + ouro duplo
  craqueDoMes,  // ⭐ Anel safira + estrelas cumulativas (1x, 2x, etc.)
  artilheiro,   // 🔥 Chama / degradê de fogo
  bronze,       // 🥉 Moldura de bronze
  silver,       // 🥈 Moldura de prata
  gold,         // 🏆 Moldura dourada pura
  diamond,      // 💎 Moldura ciano cristalina
}

/// Dados da moldura resolvida para um jogador.
class PlayerFrameInfo {
  final PlayerFrameType type;
  final int count; // ex.: 1x ou 2x para craque do mês

  const PlayerFrameInfo({
    required this.type,
    this.count = 1,
  });

  static const PlayerFrameInfo none = PlayerFrameInfo(type: PlayerFrameType.none);
}

/// Detecta a moldura do jogador com base em:
/// 1. `avatar_frame` explícito (se existir)
/// 2. `manual_badges` (conquistas como Bola de Ouro, Craque do Mês, Artilheiro)
/// 3. `monthly_highlight` e `name_effect` / `advanced_stats`
PlayerFrameInfo resolvePlayerFrame(Map<String, dynamic> player) {
  // 1. Verificação explícita caso o admin tenha salvo 'avatar_frame'
  final explicitFrame = player['avatar_frame']?.toString();
  if (explicitFrame != null && explicitFrame.isNotEmpty) {
    switch (explicitFrame) {
      case 'bola_ouro':
        return const PlayerFrameInfo(type: PlayerFrameType.bolaDeOuro);
      case 'craque_mes':
        final times = _resolveCraqueCount(player);
        return PlayerFrameInfo(type: PlayerFrameType.craqueDoMes, count: times);
      case 'artilheiro':
        return const PlayerFrameInfo(type: PlayerFrameType.artilheiro);
      case 'bronze':
        return const PlayerFrameInfo(type: PlayerFrameType.bronze);
      case 'silver':
        return const PlayerFrameInfo(type: PlayerFrameType.silver);
      case 'gold':
        return const PlayerFrameInfo(type: PlayerFrameType.gold);
      case 'diamond':
        return const PlayerFrameInfo(type: PlayerFrameType.diamond);
    }
  }

  // 2. Detecção de Bola de Ouro (em advanced_stats ou manual_badges)
  final advStats = player['advanced_stats'];
  final hasAdvBolaDeOuro = advStats is Map && advStats['bola_de_ouro'] == true;

  final badges = player['manual_badges'] as List<dynamic>? ?? [];
  bool hasBadgeBolaDeOuro = false;
  int craqueDoMesCount = 0;
  bool hasArtilheiro = false;

  for (final b in badges) {
    if (b is Map) {
      final title = (b['title'] ?? '').toString().toLowerCase();
      final icon = (b['icon'] ?? '').toString().toLowerCase();

      if (title.contains('bola de ouro') || icon.contains('bola_de_ouro')) {
        hasBadgeBolaDeOuro = true;
      }
      if (title.contains('craque do mês') ||
          title.contains('craque do mes') ||
          icon.contains('craque_do_mes')) {
        craqueDoMesCount++;
      }
      if (title.contains('chuteira') ||
          title.contains('artilheiro') ||
          icon.contains('chuteira_de_ouro')) {
        hasArtilheiro = true;
      }
    }
  }

  // Prioridade de exibição de troféus e molduras:
  // 1. Bola de Ouro (máxima glória)
  if (hasAdvBolaDeOuro || hasBadgeBolaDeOuro) {
    return const PlayerFrameInfo(type: PlayerFrameType.bolaDeOuro);
  }

  // 2. Craque do Mês — lê count de advanced_stats se disponível
  final savedCount = _resolveCraqueCount(player);
  final monthlyHighlight = player['monthly_highlight'] == true;
  if (craqueDoMesCount > 0 || monthlyHighlight || (savedCount > 1 && monthlyHighlight)) {
    final count = savedCount > 1
        ? savedCount
        : (craqueDoMesCount > 0 ? craqueDoMesCount : 1);
    return PlayerFrameInfo(type: PlayerFrameType.craqueDoMes, count: count);
  }

  // 3. Artilheiro (por badge manual)
  if (hasArtilheiro) {
    return const PlayerFrameInfo(type: PlayerFrameType.artilheiro);
  }

  // 4. Efeito extra armazenado em advanced_stats (fire / diamond)
  final extraEffect = advStats is Map
      ? advStats['name_effect_extra']?.toString()
      : null;
  if (extraEffect == 'fire') {
    return const PlayerFrameInfo(type: PlayerFrameType.artilheiro);
  }
  if (extraEffect == 'diamond') {
    return const PlayerFrameInfo(type: PlayerFrameType.diamond);
  }

  // 5. Efeito de nome base (gold / silver / bronze)
  final nameEffect = player['name_effect']?.toString();
  if (nameEffect == 'gold') {
    return const PlayerFrameInfo(type: PlayerFrameType.gold);
  }
  if (nameEffect == 'silver') {
    return const PlayerFrameInfo(type: PlayerFrameType.silver);
  }
  if (nameEffect == 'bronze') {
    return const PlayerFrameInfo(type: PlayerFrameType.bronze);
  }

  return PlayerFrameInfo.none;
}

/// Resolve quantas vezes o jogador ganhou Craque do Mês, lendo de
/// `advanced_stats.craque_mes_count` ou fallback para 1.
int _resolveCraqueCount(Map<String, dynamic> player) {
  final advStats = player['advanced_stats'];
  if (advStats is Map) {
    final v = advStats['craque_mes_count'];
    if (v is num) return v.toInt();
  }
  // Também aceita craque_mes_count no nível raiz (compatibilidade)
  final root = player['craque_mes_count'];
  if (root is num) return root.toInt();
  return 1;
}

/// Retorna uma sombra limpa de elevação física para o card no campo ou elenco.
BoxShadow? getCardAuraShadow(PlayerFrameInfo frame) {
  if (frame.type == PlayerFrameType.none) return null;
  return BoxShadow(
    color: Colors.black.withValues(alpha: 0.35),
    blurRadius: 4,
    offset: const Offset(0, 2),
  );
}

/// Widget universal que decora o avatar com uma moldura estilizada.
/// Funciona tanto para avatares circulares (`CircleAvatar`) quanto retangulares (`FifaCard`).
class PlayerAvatarFrame extends StatelessWidget {
  final Widget child;
  final PlayerFrameInfo frame;
  final bool compact;
  final bool isCircular;

  const PlayerAvatarFrame({
    super.key,
    required this.child,
    required this.frame,
    this.compact = false,
    this.isCircular = true,
  });

  @override
  Widget build(BuildContext context) {
    if (frame.type == PlayerFrameType.none) {
      return child;
    }

    final double borderWidth = compact ? 1.8 : 2.5;

    switch (frame.type) {
      case PlayerFrameType.bolaDeOuro:
        return _buildBolaDeOuroFrame(borderWidth);
      case PlayerFrameType.craqueDoMes:
        return _buildCraqueDoMesFrame(borderWidth);
      case PlayerFrameType.artilheiro:
        return _buildArtilheiroFrame(borderWidth);
      case PlayerFrameType.bronze:
        return _buildMetalFrame(
          colors: const [Color(0xFFE8974D), Color(0xFFCD7F32), Color(0xFF8C501E)],
          borderWidth: borderWidth,
        );
      case PlayerFrameType.silver:
        return _buildMetalFrame(
          colors: const [Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
          borderWidth: borderWidth,
        );
      case PlayerFrameType.gold:
        return _buildMetalFrame(
          colors: const [Color(0xFFFFF275), Color(0xFFFFD700), Color(0xFFB8860B)],
          borderWidth: borderWidth,
        );
      case PlayerFrameType.diamond:
        return _buildMetalFrame(
          colors: const [Color(0xFFE2F1F8), Color(0xFF38BDF8), Color(0xFF0284C7)],
          borderWidth: borderWidth,
        );
      case PlayerFrameType.none:
        return child;
    }
  }

  // 👑 BOLA DE OURO: Coroa Real no Topo + Aro Dourado Nobre
  Widget _buildBolaDeOuroFrame(double borderWidth) {
    final crownSize = compact ? 11.0 : 16.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(borderWidth),
          decoration: BoxDecoration(
            shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircular ? null : BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF9A6),
                Color(0xFFFFD700),
                Color(0xFFFFA000),
                Color(0xFFFFD700),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: compact ? 3 : 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
        // Mini coroa dourada no topo
        Positioned(
          top: compact ? -5 : -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.military_tech_rounded,
                  color: const Color(0xFFFFD700),
                  size: crownSize,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ⭐ CRAQUE DO MÊS: Anel Safira/Ouro + Estrelas Cumulativas no Rodapé
  Widget _buildCraqueDoMesFrame(double borderWidth) {
    final count = frame.count;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(borderWidth),
          decoration: BoxDecoration(
            shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircular ? null : BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF38BDF8),
                Color(0xFF1D4ED8),
                Color(0xFFFFD700),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: compact ? 3 : 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
        // Badge de estrelas cumulativas no rodapé
        Positioned(
          bottom: compact ? -5 : -8,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: count > 1 ? 4 : 2,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: AppColors.headerBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count > 2) ...[
                  Text(
                    '$count',
                    style: TextStyle(
                      color: const Color(0xFFFFD700),
                      fontSize: compact ? 8 : 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Icon(
                    Icons.star_rounded,
                    color: const Color(0xFFFFD700),
                    size: compact ? 10 : 13,
                  ),
                ] else ...[
                  for (int i = 0; i < count; i++)
                    Icon(
                      Icons.star_rounded,
                      color: const Color(0xFFFFD700),
                      size: compact ? 10 : 13,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 ARTILHEIRO DA TEMPORADA: Moldura de Fogo + Ícone de Chama
  Widget _buildArtilheiroFrame(double borderWidth) {
    final flameSize = compact ? 10.0 : 14.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(borderWidth),
          decoration: BoxDecoration(
            shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircular ? null : BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFEA00),
                Color(0xFFFF6D00),
                Color(0xFFDD2C00),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: compact ? 3 : 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
        // Mini chama no topo direito
        Positioned(
          top: compact ? -4 : -6,
          right: compact ? -4 : -6,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF6D00), width: 1),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 3),
              ],
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: const Color(0xFFFFAB00),
              size: flameSize,
            ),
          ),
        ),
      ],
    );
  }

  // Moldura Metálica com Gradiente
  Widget _buildMetalFrame({
    required List<Color> colors,
    required double borderWidth,
  }) {
    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: compact ? 3 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

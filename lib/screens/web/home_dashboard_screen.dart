import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:app_do_fut/screens/tournament_dashboard_screen.dart';
import 'package:app_do_fut/services/dashboard_store.dart';
import 'package:app_do_fut/utils/dashboard_highlights.dart';
import 'package:app_do_fut/widgets/shared/ranking_player_bits.dart';
import 'package:app_do_fut/models/milestone_update.dart';
import 'package:app_do_fut/services/avatar_style_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_do_fut/app/app_services.dart';

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String _nomeMes(String key) {
  final p = key.split('-');
  return '${_meses[int.parse(p[1]) - 1]} de ${p[0]}';
}

String _dataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Aba "Início": painel com destaques do mês e última pelada.
/// O cálculo é feito uma vez no [DashboardStore]; aqui só se desenha.
class HomeDashboardScreen extends StatefulWidget {
  final String groupId;
  final String? groupName;

  const HomeDashboardScreen({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  String? _myPlayerName;
  String? _myPlayerId;
  int _updateTabFilter = 0; // 0 = Todas (Grupo), 1 = Minhas Notificações (Você)
  bool _showAllUpdates = false;

  @override
  void initState() {
    super.initState();
    // Depois do primeiro quadro: assim o esqueleto aparece antes da conta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DashboardStore.instance.ensure(widget.groupId);
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    if (kIsWeb || !AppServices.instance.features.hasAuth) return;
    try {
      final membership = await AppServices.instance.members.getMyMembership(widget.groupId);
      if (membership != null && mounted) {
        setState(() {
          _myPlayerId = membership.playerId;
          _myPlayerName = membership.player?.name ?? membership.player?.displayName;
        });
      }
    } catch (_) {}
  }

  void _openPlayer(String id, String name, String? icon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerDetailScreen(
          groupId: widget.groupId,
          playerId: id,
          initialPlayerName: name,
          playerIcon: icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DashboardStatus>(
      valueListenable: DashboardStore.instance.status,
      builder: (_, st, _) {
        final data = DashboardStore.instance.data;
        if (data == null || data.groupId != widget.groupId) {
          if (st == DashboardStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível carregar o início.',
                        style: TextStyle(color: AppColors.textWhite)),
                    TextButton(
                      onPressed: () => DashboardStore.instance
                          .ensure(widget.groupId, force: true),
                      child: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue));
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildWelcomeHero(data),
                _updatesCard(data),
                _monthCard(
                  'Destaque do mês · ${_nomeMes(data.currentMonth)} (parcial)',
                  data.currentTop,
                  data.currentMatches,
                  data,
                  icon: Icons.emoji_events,
                  iconColor: Colors.amber,
                ),
                _monthCard(
                  'Destaque do mês anterior · ${_nomeMes(data.previousMonth)}',
                  data.previousTop,
                  data.previousMatches,
                  data,
                  icon: Icons.history,
                  iconColor: AppColors.textDim,
                ),
                if (data.officialCraques.isNotEmpty) _craqueCard(data),
                _lastSessionCard(data),
                _scorerCard(
                  'Artilheiro do mês',
                  Icons.sports_soccer,
                  data.currentScorer,
                  data.previousScorer,
                  (p) => '${p.goals} ${p.goals == 1 ? 'gol' : 'gols'}',
                  data,
                ),
                _scorerCard(
                  'Garçom do mês',
                  Icons.handshake_outlined,
                  data.currentAssister,
                  data.previousAssister,
                  (p) =>
                      '${p.assists} ${p.assists == 1 ? 'assistência' : 'assistências'}',
                  data,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHero(DashboardData data) {
    final hasUser = !kIsWeb && _myPlayerName != null && _myPlayerName!.isNotEmpty;
    final groupTitle = (widget.groupName != null && widget.groupName!.isNotEmpty)
        ? widget.groupName!
        : 'Pelada';

    final welcomeText = hasUser
        ? 'Bem-vindo ao $groupTitle, $_myPlayerName!'
        : 'Bem-vindo ao $groupTitle!';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A6E),
            AppColors.headerBlue,
            AppColors.deepBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  color: AppColors.accentBlueLight,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      welcomeText,
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Acompanhe os destaques, resultados e estatísticas do grupo.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data.lastSession != null || data.currentTop.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (data.lastSession != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event, size: 13, color: AppColors.accentBlueLight),
                        const SizedBox(width: 5),
                        Text(
                          'Última pelada: ${_dataBr(data.lastSession!.date)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                if (data.currentTop.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 13, color: Colors.amber),
                        const SizedBox(width: 5),
                        Text(
                          'Top 1 do mês: ${data.currentTop.first.name}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(
    String title,
    Widget child, {
    VoidCallback? onTap,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (iconColor ?? AppColors.accentBlue).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: iconColor ?? AppColors.accentBlueLight,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textDim,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) => Text(text,
      style: const TextStyle(color: AppColors.textDim, fontSize: 13));

  Widget _avatar(DashboardData d, String id, String name, String? icon,
      {double size = 40}) {
    return RankAvatar(
      player: d.playerMaps[id] ?? {'id': id, 'name': name, 'icon': icon},
      size: size,
      contextType: AvatarContext.dashboard,
    );
  }

  Widget _updatesCard(DashboardData d) {
    final hasUserFilter =
        !kIsWeb && _myPlayerId != null && _myPlayerId!.isNotEmpty;
    final allUpdates = d.updates;
    final myUpdates = hasUserFilter
        ? allUpdates.where((u) => u.playerId == _myPlayerId).toList()
        : <MilestoneUpdate>[];
    final displayedUpdates = (_updateTabFilter == 1 && hasUserFilter)
        ? myUpdates
        : allUpdates;

    return _card(
      'Atualizações Recentes',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasUserFilter) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(
                      'Todas (${allUpdates.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _updateTabFilter == 0
                            ? AppColors.textWhite
                            : AppColors.textMuted,
                      ),
                    ),
                    selected: _updateTabFilter == 0,
                    selectedColor: AppColors.accentBlue,
                    backgroundColor: AppColors.deepBlue,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _updateTabFilter = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Minhas Notificações (${myUpdates.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _updateTabFilter == 1
                            ? AppColors.textWhite
                            : AppColors.textMuted,
                      ),
                    ),
                    selected: _updateTabFilter == 1,
                    selectedColor: AppColors.accentBlue,
                    backgroundColor: AppColors.deepBlue,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _updateTabFilter = 1),
                  ),
                ],
              ),
            ),
          ],
          if (displayedUpdates.isEmpty)
            _empty(
              _updateTabFilter == 1
                  ? 'Você ainda não possui marcas históricas alcançadas.'
                  : 'Nenhuma atualização recente no grupo ainda.',
            )
          else ...[
            for (final u in displayedUpdates.take(_showAllUpdates ? 50 : 5))
              InkWell(
                onTap: () =>
                    _openPlayer(u.playerId, u.playerName, u.playerIcon),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                  child: Row(
                    children: [
                      _avatar(d, u.playerId, u.playerName, u.playerIcon,
                          size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.title,
                              style: const TextStyle(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _dataBr(u.date),
                                  style: const TextStyle(
                                    color: AppColors.textDim,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    u.description,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: u.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(u.icon, color: u.color, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            if (displayedUpdates.length > 5) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showAllUpdates = !_showAllUpdates),
                  child: Text(
                    _showAllUpdates
                        ? 'Mostrar menos'
                        : 'Ver todas (${displayedUpdates.length})',
                    style: const TextStyle(
                      color: AppColors.accentBlueLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
      icon: Icons.trending_up,
      iconColor: AppColors.highlightGreen,
    );
  }

  Widget _playerRow(DashboardData d, PlayerMonthStat p, String detail,
      {int? position}) {
    Color? posColor;
    if (position == 1) posColor = AppColors.tierGold;
    if (position == 2) posColor = AppColors.tierSilver;
    if (position == 3) posColor = AppColors.tierBronzeAccent;

    return InkWell(
      onTap: () => _openPlayer(p.playerId, p.name, p.icon),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            if (position != null)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                alignment: Alignment.center,
                decoration: posColor != null
                    ? BoxDecoration(
                        color: posColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: posColor.withValues(alpha: 0.6), width: 1.5),
                      )
                    : null,
                child: Text(
                  '$position',
                  style: TextStyle(
                    color: posColor ?? AppColors.textDim,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            _avatar(d, p.playerId, p.name, p.icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthCard(
    String title,
    List<PlayerMonthStat> top,
    int matches,
    DashboardData d, {
    IconData? icon,
    Color? iconColor,
  }) {
    Widget body;
    if (top.isEmpty) {
      body = _empty(matches == 0
          ? 'Sem peladas neste mês.'
          : 'Poucos jogos neste mês (mínimo de $kHighlightMinMatches jogos por jogador).');
    } else {
      body = Column(
        children: [
          for (var i = 0; i < top.length; i++)
            _playerRow(
              d,
              top[i],
              '${top[i].goals} gols · ${top[i].assists} assist. · ${top[i].matches} jogos',
              position: i + 1,
            ),
        ],
      );
    }
    return _card(title, body, icon: icon, iconColor: iconColor);
  }

  Widget _craqueCard(DashboardData d) {
    return _card(
      'Craque do mês (selo oficial)',
      Column(
        children: [
          for (final PlayerModel p in d.officialCraques)
            InkWell(
              onTap: () => _openPlayer(p.id, p.displayName, p.icon),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    _avatar(d, p.id, p.displayName, p.icon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.displayName,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.military_tech, color: Colors.amber, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
      icon: Icons.star,
      iconColor: Colors.amber,
    );
  }

  Widget _lastSessionCard(DashboardData d) {
    final s = d.lastSession;
    if (s == null) {
      return _card('Última pelada', _empty('Sem peladas ainda.'), icon: Icons.sports_soccer);
    }
    final goleada = s.bigWinWinner == null
        ? 'Sem goleada registrada'
        : '${s.bigWinWinner == 'red' ? 'Vermelho' : 'Branco'} ${s.bigWinRedScore} x ${s.bigWinWhiteScore}';
    final artilheiros = s.topScorers.isEmpty
        ? 'Ninguém marcou'
        : '${s.topScorers.map((p) => p.name).join(', ')} (${s.topScorers.first.goals})';

    return _card(
      'Última pelada',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.deepBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: AppColors.accentBlueLight),
                const SizedBox(width: 8),
                Text(
                  '${s.name.isEmpty ? 'Pelada' : s.name} · ${_dataBr(s.date)}',
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statBadge('Partidas', '${s.matches}', Icons.sports),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBadge('Gols Feitos', '${s.totalGoals}', Icons.sports_soccer),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _line('Maior goleada', goleada),
          _line('Artilharia do dia', artilheiros),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Toque para ver o resumo completo ➔',
              style: TextStyle(
                color: AppColors.accentBlueLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      icon: Icons.sports_soccer,
      iconColor: AppColors.highlightGreen,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDashboardScreen(
            groupId: widget.groupId,
            tournamentId: s.sessionId,
            tournamentName: s.name,
            totalPlayers: 0,
          ),
        ),
      ),
    );
  }

  Widget _statBadge(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accentBlueLight),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                k,
                style: const TextStyle(color: AppColors.textDim, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
              ),
            ),
          ],
        ),
      );

  Widget _scorerCard(
    String title,
    IconData icon,
    PlayerMonthStat? current,
    PlayerMonthStat? previous,
    String Function(PlayerMonthStat) label,
    DashboardData d,
  ) {
    final isGarcom = title.startsWith('Garçom');
    String detail(PlayerMonthStat p) => isGarcom
        ? '${p.assists} ${p.assists == 1 ? 'assistência' : 'assistências'}'
        : label(p);
    return _card(
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current == null)
            _empty('Poucos jogos neste mês')
          else
            _playerRow(d, current, detail(current)),
          const SizedBox(height: 6),
          Text(
            previous == null
                ? 'Mês passado: sem destaque'
                : 'Mês passado: ${previous.name} (${detail(previous)})',
            style: const TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
        ],
      ),
      icon: icon,
      iconColor: isGarcom ? AppColors.accentBlueLight : AppColors.highlightGreen,
    );
  }
}

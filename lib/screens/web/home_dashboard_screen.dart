import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/models/player_model.dart';
import 'package:app_do_fut/screens/player_detail.dart';
import 'package:app_do_fut/screens/tournament_dashboard_screen.dart';
import 'package:app_do_fut/services/dashboard_store.dart';
import 'package:app_do_fut/utils/dashboard_highlights.dart';
import 'package:app_do_fut/widgets/shared/ranking_player_bits.dart';
import 'package:flutter/material.dart';

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

/// Aba "Início": painel somente leitura com destaques do mês e última pelada.
/// O cálculo é feito uma vez no [DashboardStore]; aqui só se desenha.
class HomeDashboardScreen extends StatefulWidget {
  final String groupId;
  const HomeDashboardScreen({super.key, required this.groupId});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Depois do primeiro quadro: assim o esqueleto aparece antes da conta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DashboardStore.instance.ensure(widget.groupId);
    });
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
      builder: (_, st, __) {
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
                _monthCard(
                  'Destaque do mês · ${_nomeMes(data.currentMonth)} (parcial)',
                  data.currentTop,
                  data.currentMatches,
                  data,
                ),
                _monthCard(
                  'Destaque do mês · ${_nomeMes(data.previousMonth)}',
                  data.previousTop,
                  data.previousMatches,
                  data,
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

  Widget _card(String title, Widget child, {VoidCallback? onTap}) {
    return Card(
      color: AppColors.surfaceElevated,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 10),
              child,
            ],
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
    );
  }

  Widget _playerRow(DashboardData d, PlayerMonthStat p, String detail,
      {int? position}) {
    return InkWell(
      onTap: () => _openPlayer(p.playerId, p.name, p.icon),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (position != null)
              SizedBox(
                width: 22,
                child: Text('$position',
                    style: const TextStyle(
                        color: AppColors.textDim, fontWeight: FontWeight.bold)),
              ),
            _avatar(d, p.playerId, p.name, p.icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w600)),
                  Text(detail,
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthCard(
      String title, List<PlayerMonthStat> top, int matches, DashboardData d) {
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
    return _card(title, body);
  }

  Widget _craqueCard(DashboardData d) {
    return _card(
      'Craque do mês (selo oficial)',
      Column(
        children: [
          for (final PlayerModel p in d.officialCraques)
            InkWell(
              onTap: () => _openPlayer(p.id, p.displayName, p.icon),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _avatar(d, p.id, p.displayName, p.icon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(p.displayName,
                          style: const TextStyle(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lastSessionCard(DashboardData d) {
    final s = d.lastSession;
    if (s == null) {
      return _card('Última pelada', _empty('Sem peladas ainda.'));
    }
    final goleada = s.bigWinWinner == null
        ? 'sem goleada'
        : '${s.bigWinWinner == 'red' ? 'Vermelho' : 'Branco'} '
            '${s.bigWinRedScore} x ${s.bigWinWhiteScore}';
    final artilheiros = s.topScorers.isEmpty
        ? 'ninguém marcou'
        : '${s.topScorers.map((p) => p.name).join(', ')} '
            '(${s.topScorers.first.goals})';
    return _card(
      'Última pelada',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${s.name.isEmpty ? 'Pelada' : s.name} · ${_dataBr(s.date)}',
              style: const TextStyle(
                  color: AppColors.textWhite, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _line('Partidas', '${s.matches}'),
          _line('Gols', '${s.totalGoals}'),
          _line('Maior goleada', goleada),
          _line('Artilheiro', artilheiros),
        ],
      ),
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

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(k,
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 13))),
            Expanded(
                child: Text(v,
                    style: const TextStyle(
                        color: AppColors.textWhite, fontSize: 13))),
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
          const SizedBox(height: 4),
          Text(
            previous == null
                ? 'Mês passado: sem destaque'
                : 'Mês passado: ${previous.name} (${detail(previous)})',
            style: const TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/session_model.dart';
import '../repositories/supabase_service.dart';
import '../utils/session_grouping.dart';
import '../widgets/session/session_delete_dialog.dart';
import '../widgets/session/session_form_sheet.dart';
import '../widgets/session/session_list_tile.dart';
import 'tournament_dashboard_screen.dart';

class SessionsScreen extends StatefulWidget {
  final String groupId;

  const SessionsScreen({super.key, required this.groupId});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<SessionModel> sessions = [];
  bool isLoading = true;
  bool _isAdmin = false;
  // sessionId -> confirmados (mapas de jogador, na ordem de chegada)
  Map<String, List<Map<String, dynamic>>> _participants = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await SupabaseService.instance.groupMembers.isCurrentUserAdmin(widget.groupId);
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadSessions() async {
    setState(() => isLoading = true);
    try {
      final fetched = await SupabaseService.instance.sessions
          .getSessionsByGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        sessions = fetched;
      });
      await _loadParticipants(fetched);
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Avatares dos confirmados são decorativos: falha (offline) não bloqueia a lista.
  Future<void> _loadParticipants(List<SessionModel> fetched) async {
    try {
      final idsBySession = await SupabaseService.instance.sessionArrivals
          .getPlayerIdsBySessions(fetched.map((s) => s.id).toList());
      if (idsBySession.isEmpty) return;
      final players =
          await SupabaseService.instance.players.getPlayersByGroup(widget.groupId);
      final byId = {
        for (final p in players) p.id: {...p.toMap(), ...p.cosmeticsToMap()},
      };
      if (!mounted) return;
      setState(() {
        _participants = {
          for (final e in idsBySession.entries)
            e.key: [
              for (final id in e.value)
                if (byId[id] != null) byId[id]!,
            ],
        };
      });
    } catch (e) {
      debugPrint('Error loading session participants: $e');
    }
  }

  Future<void> _openSessionForm({SessionModel? existing}) async {
    await showSessionFormSheet(
      context,
      existing: existing,
      onSubmit: (SessionModel session) async {
        // Gets the current season to link to the session
        final currentSeason = await SupabaseService.instance.seasons
            .getCurrentSeason(widget.groupId);

        final model = SessionModel(
          id: existing?.id ?? session.id,
          groupId: widget.groupId,
          seasonId: currentSeason?.id,
          title: session.title,
          sessionDate: session.dateTime ?? DateTime.now(),
          status: session.isLive
              ? SessionModel.statusInProgress
              : SessionModel.statusFinished,
          durationMinutes: session.durationMinutes,
          winLimit: (session.winLimit ?? 0) > 0 ? session.winLimit : null,
          playerCount: session.playerCount,
          streakAction: session.streakAction,
          draftMode: session.draftMode,
        );

        try {
          if (existing == null) {
            await SupabaseService.instance.sessions.createSession(model);
          } else {
            await SupabaseService.instance.sessions.updateSession(model.copyWith(id: existing.id));
          }
          await _loadSessions();
        } catch (e) {
          debugPrint('Error saving session: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao salvar: ${e.toString()}')),
            );
          }
        }
      },
    );
  }

  Future<void> _confirmDeleteSession(SessionModel session) async {
    final bool confirmed = await showSessionDeleteDialog(context);
    if (!confirmed) return;

    setState(() => isLoading = true);
    try {
      await SupabaseService.instance.sessions.deleteSession(session.id);
      await _loadSessions();
    } catch (e) {
      debugPrint('Error deleting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildTile(SessionModel item) {
    return SessionListTile(
      session: item,
      participants: _participants[item.id] ?? const [],
      onOpen: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentDashboardScreen(
              groupId: widget.groupId,
              tournamentId: item.id,
              tournamentName: item.title,
              totalPlayers: item.playerCount,
            ),
          ),
        );
      },
      onEdit: _isAdmin ? () => _openSessionForm(existing: item) : _denyPermission,
      onDelete: _isAdmin ? () => _confirmDeleteSession(item) : _denyPermission,
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupSessionsByMonth(sessions);
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: isLoading && sessions.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue))
          : RefreshIndicator(
              color: AppColors.accentBlue,
              backgroundColor: AppColors.surfaceElevated,
              onRefresh: _loadSessions,
              child: sessions.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [_EmptySessions()],
                    )
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        for (final group in groups)
                          SliverMainAxisGroup(
                            slivers: [
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _MonthHeaderDelegate(group.title),
                              ),
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                sliver: SliverList.builder(
                                  itemCount: group.sessions.length,
                                  itemBuilder: (_, i) =>
                                      _buildTile(group.sessions[i]),
                                ),
                              ),
                            ],
                          ),
                        // margem para o botão flutuante não cobrir o último card
                        const SliverToBoxAdapter(child: SizedBox(height: 72)),
                      ],
                    ),
            ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              backgroundColor: AppColors.accentBlue,
              onPressed: () => _openSessionForm(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _denyPermission() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Apenas administradores podem alterar as peladas.')),
    );
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  const _MonthHeaderDelegate(this.title);

  static const double _height = 40;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? AppColors.borderSubtle : Colors.transparent,
          ),
        ),
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate old) => old.title != title;
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.22),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.headerBlue,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Icon(Icons.sports_soccer,
                size: 44, color: AppColors.textDim),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma pelada criada neste grupo.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Puxe para atualizar ou crie a primeira no botão +.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

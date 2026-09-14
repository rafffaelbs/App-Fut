import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/session_model.dart';
import '../repositories/supabase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSessions();
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
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _openSessionForm({SessionModel? existing}) async {
    await showSessionFormSheet(
      context,
      existing: existing,
      onSubmit: (SessionModel session) async {
        // Obtém a temporada atual para vincular a sessão
        final currentSeason = await SupabaseService.instance.seasons
            .getCurrentSeason(widget.groupId);

        final model = SessionModel(
          id: existing?.id ?? '',
          seasonId: currentSeason?.id,
          title: session.title,
          timestamp: session.dateTime ?? DateTime.now(),
          status: session.isLive
              ? SessionModel.statusEmAndamento
              : SessionModel.statusFinalizada,
          durationMinutes: session.durationMinutes,
          winLimit: (session.winLimit ?? 0) > 0 ? session.winLimit : null,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue))
          : sessions.isEmpty
              ? const Center(
                  child: Text(
                    "Nenhuma pelada criada neste grupo.",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SessionModel item = sessions[index];
                    return SessionListTile(
                      session: item,
                      onOpen: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TournamentDashboardScreen(
                              groupId: widget.groupId,
                              tournamentId: item.id,
                              tournamentName: item.title,
                              totalPlayers: item.jogadores,
                            ),
                          ),
                        );
                      },
                      onEdit: () => _openSessionForm(existing: item),
                      onDelete: () => _confirmDeleteSession(item),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        onPressed: () => _openSessionForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

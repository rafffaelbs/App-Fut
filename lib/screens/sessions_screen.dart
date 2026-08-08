import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/session.dart';
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
  List<Session> sessions = [];
  bool isLoading = true;

  String get _storageKey => 'sessions_${widget.groupId}';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        final loaded = decoded
            .whereType<Map>()
            .map((item) => Session.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        loaded.sort((Session a, Session b) {
          final DateTime dateA = a.dateTime ?? DateTime(1970);
          final DateTime dateB = b.dateTime ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
        setState(() => sessions = loaded);
      } catch (_) {
        // Dados corrompidos: ignora e mantém lista vazia.
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> data =
        sessions.map((Session s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> _openSessionForm({Session? existing}) async {
    await showSessionFormSheet(
      context,
      existing: existing,
      onSubmit: (Session session) {
        setState(() {
          final List<Session> updated = [...sessions];
          final int index = updated.indexWhere((s) => s.id == session.id);
          if (index >= 0) {
            updated[index] = session;
          } else {
            updated.insert(0, session);
          }
          sessions = updated;
        });
        _saveSessions();
      },
    );
  }

  Future<void> _confirmDeleteSession(Session session) async {
    final bool confirmed = await showSessionDeleteDialog(context);
    if (!confirmed) return;
    setState(() {
      sessions = sessions.where((s) => s.id != session.id).toList();
    });
    _saveSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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
                    final Session item = sessions[index];
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
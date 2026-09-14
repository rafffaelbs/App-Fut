import 'dart:convert';
import 'dart:io';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/edit_match_screen.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/supabase_service.dart';

class HistoryScreen extends StatefulWidget {
  final String tournamentId;
  final String groupId;

  const HistoryScreen({
    super.key,
    required this.tournamentId,
    required this.groupId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> history = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Map<String, String> _idToName = {};

  /// Converte PartidaModel para o mapa dinâmico que a UI já consome.
  Map<String, dynamic> _toLegacyMatch(dynamic partida) {
    final redPlayers = partida.escalacao
        .where((e) => e.isRed || e.isTeamA || e.team.toLowerCase() == 'red')
        .map((e) => {
              'name': _idToName[e.playerId] ?? e.player?.name ?? e.player?.nome ?? e.playerId,
              'id': e.playerId
            })
        .toList();
    final whitePlayers = partida.escalacao
        .where((e) => e.isWhite || e.isTeamB || e.team.toLowerCase() == 'white')
        .map((e) => {
              'name': _idToName[e.playerId] ?? e.player?.name ?? e.player?.nome ?? e.playerId,
              'id': e.playerId
            })
        .toList();

    final events = partida.eventos.map<Map<String, dynamic>>((ev) {
      final playerName = _idToName[ev.playerId] ?? ev.player?.name ?? ev.player?.nome ?? ev.playerId;
      final assistName = ev.assistPlayerId != null
          ? (_idToName[ev.assistPlayerId!] ?? ev.assistPlayer?.name ?? ev.assistPlayer?.nome)
          : null;

      return {
        'type': ev.eventType,
        'playerId': ev.playerId,
        'player': playerName,
        'assistId': ev.assistPlayerId,
        'assist': assistName,
        'team': ev.team ?? 'red',
        'time': ev.minute ?? ev.timestamp ?? '',
      };
    }).toList();

    String durationMin;
    if (partida.duracaoSegundos != null) {
      final secs = partida.duracaoSegundos!;
      durationMin = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    } else if (partida.matchDuration != null && partida.matchDuration!.isNotEmpty) {
      durationMin = partida.matchDuration!;
    } else {
      durationMin = '—';
    }

    return {
      'id': partida.id,
      'session_id': partida.sessionId,
      'start_time': partida.startTime?.toIso8601String(),
      'end_time': partida.endTime?.toIso8601String(),
      'date': partida.timestamp.toIso8601String(),
      'scoreRed': partida.scoreRed,
      'scoreWhite': partida.scoreWhite,
      'match_duration': durationMin,
      'players': {'red': redPlayers, 'white': whitePlayers},
      'events': events,
    };
  }

  Future<void> _loadHistory() async {
    setState(() => isLoading = true);
    try {
      if (widget.groupId.isNotEmpty) {
        try {
          final groupPlayers = await SupabaseService.instance.players.getJogadoresDoGrupo(widget.groupId);
          for (final p in groupPlayers) {
            _idToName[p.id] = p.displayName;
          }
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      final String historyKey = 'match_history_${widget.tournamentId}';
      List<dynamic> localHistory = [];
      if (prefs.containsKey(historyKey)) {
        try {
          final localData = jsonDecode(prefs.getString(historyKey)!);
          if (localData is List) localHistory = localData;
        } catch (_) {}
      }

      String defaultDuration = '08:00';
      final sessionsData = prefs.getString('sessions_${widget.groupId}');
      if (sessionsData != null) {
        try {
          final List<dynamic> allSessions = jsonDecode(sessionsData);
          final currentSession = allSessions.firstWhere(
            (s) => s['id'] == widget.tournamentId,
            orElse: () => null,
          );
          if (currentSession != null && currentSession['duration'] != null) {
            defaultDuration = '${currentSession['duration'].toString().padLeft(2, '0')}:00';
          }
        } catch (_) {}
      }

      final partidas = await SupabaseService.instance.partidas
          .getPartidasPorSessao(widget.tournamentId);

      List<dynamic> mapped = partidas.map(_toLegacyMatch).toList();
      
      // Fallback local caso o Supabase ainda não tenha partidas sincronizadas
      if (mapped.isEmpty) {
        mapped = localHistory;
      } else {
        // Enriquece partidas do Supabase com a duração real salva localmente
        for (int i = 0; i < mapped.length; i++) {
          if (mapped[i]['match_duration'] == '—' || mapped[i]['match_duration'] == null) {
            final matchingLocal = localHistory.firstWhere(
              (loc) => loc['id'] == mapped[i]['id'] || (loc['scoreRed'] == mapped[i]['scoreRed'] && loc['scoreWhite'] == mapped[i]['scoreWhite']),
              orElse: () => null,
            );
            if (matchingLocal != null && matchingLocal['match_duration'] != null) {
              mapped[i]['match_duration'] = matchingLocal['match_duration'];
            } else if (i < localHistory.length && localHistory[i]['match_duration'] != null) {
              mapped[i]['match_duration'] = localHistory[i]['match_duration'];
            } else {
              mapped[i]['match_duration'] = defaultDuration;
            }
          }
        }
      }

      mapped.sort((a, b) {
        final dateA = DateTime.parse(a['date'] ?? '1970-01-01');
        final dateB = DateTime.parse(b['date'] ?? '1970-01-01');
        return dateB.compareTo(dateA);
      });

      setState(() => history = mapped);
    } catch (e) {
      debugPrint('Error loading history: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final String historyKey = 'match_history_${widget.tournamentId}';
        if (prefs.containsKey(historyKey)) {
          final localData = jsonDecode(prefs.getString(historyKey)!);
          if (localData is List) {
            setState(() => history = localData);
          }
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  Future<void> _exportHistory() async {
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nada para exportar!")));
      return;
    }

    try {
      String jsonString = const JsonEncoder.withIndent('  ').convert(history);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/match_history_full.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'Backup Completo das Partidas');
    } catch (e) {
      debugPrint("Erro ao exportar: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao criar arquivo de exportação.")),
      );
    }
  }

  Future<void> _clearHistory() async {
    setState(() => isLoading = true);
    try {
      // Deleta cada partida individualmente para garantir que o repositório
      // exclua em cascata os eventos, escalações e histórico de ratings associados.
      for (final match in history) {
        if (match['id'] != null) {
          await SupabaseService.instance.partidas.deletarPartida(match['id']);
        }
      }
      await _loadHistory();
    } catch (e) {
      debugPrint('Error clearing history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao limpar histórico: ${e.toString()}')),
        );
      }
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _promptPasswordForEdit(int matchIndex, Map<String, dynamic> matchData) {
    final TextEditingController passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text("Acesso Restrito", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: passController,
          obscureText: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (passController.text == "0101") {
                Navigator.pop(ctx); 

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditMatchScreen(
                      tournamentId: widget.tournamentId,
                      matchIndex: matchIndex,
                      matchData: matchData,
                      groupId: widget.groupId,
                    ),
                  ),
                );

                if (result == true) {
                  _loadHistory();
                }
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Senha Incorreta!"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Entrar", style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text("Histórico", style: TextStyle(color: AppColors.textWhite)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.greenAccent),
            onPressed: _exportHistory,
            tooltip: "Exportar",
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: AppColors.headerBlue,
                  title: const Text("Limpar Tudo?", style: TextStyle(color: AppColors.textWhite)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
                    TextButton(onPressed: () { Navigator.pop(c); _clearHistory(); }, child: const Text("Limpar", style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text("Sem partidas.", style: TextStyle(color: Colors.white38)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final match = history[index];
                final String duration = match['match_duration'] ?? 'N/A';
                
                // Extraindo as listas de jogadores 
                final List<dynamic> redTeam = match['players']?['red'] ?? [];
                final List<dynamic> whiteTeam = match['players']?['white'] ?? [];

                return GestureDetector(
                  onLongPress: () => _showDebugInfo(match),
                  child: Card(
                  color: AppColors.headerBlue,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white54,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.accentBlue, size: 20),
                          onPressed: () => _promptPasswordForEdit(index, match),
                        ),
                        const Icon(Icons.expand_more, color: Colors.white54),
                      ],
                    ),
                    title: FittedBox( // O Segredo contra o Overflow!
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Vermelho ", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            "${match['scoreRed']} x ${match['scoreWhite']}",
                            style: const TextStyle(color: AppColors.textWhite, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const Text(" Branco", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text("Duração: $duration", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    children: [
                      const Divider(color: Colors.white12),
                      
                      // --- NOVA SEÇÃO: ESCALAÇÃO DA PARTIDA ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("🔴 Time Vermelho", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  ...redTeam.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Text(p['name'] ?? 'Desconhecido', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  )),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("⚪ Time Branco", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  ...whiteTeam.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Text(p['name'] ?? 'Desconhecido', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(color: Colors.white12),
                      
                      // --- SEÇÃO ORIGINAL: EVENTOS (GOLS/CARTÕES) ---
                      if (match['events'] != null && (match['events'] as List).isNotEmpty)
                        ...((match['events'] as List).map((event) {
                          return ListTile(
                            dense: true,
                            leading: _getEventIcon(event['type']),
                            title: Text("${event['player']} (${event['team']})", style: const TextStyle(color: AppColors.textWhite)),
                            subtitle: Text(_getEventDescription(event), style: const TextStyle(color: Colors.white54)),
                            trailing: Text(event['time'] ?? '', style: const TextStyle(color: Colors.grey)),
                          );
                        }))
                      else
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("Nenhum evento registrado.", style: TextStyle(color: Colors.grey)),
                        ),
                    ],
                  ),
                ));
              },
            ),
    );
  }

  void _showDebugInfo(Map<String, dynamic> match) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final rows = <_DebugRow>[
          _DebugRow('match_id', match['id']?.toString() ?? '—'),
          _DebugRow('session_id', match['session_id']?.toString() ?? '—'),
          _DebugRow('start_time', match['start_time']?.toString() ?? '—'),
          _DebugRow('end_time', match['end_time']?.toString() ?? '—'),
          _DebugRow('date', match['date']?.toString() ?? '—'),
          _DebugRow('duration', match['match_duration']?.toString() ?? '—'),
          _DebugRow('score', '${match['scoreRed']} x ${match['scoreWhite']}'),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Debug Info',
                style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(r.label,
                        style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                    ),
                    Expanded(
                      child: SelectableText(r.value,
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  String _getEventDescription(Map<String, dynamic> event) {
    if (event['type'] == 'goal') {
      if (event['assist'] != null && event['assist'].toString().isNotEmpty) {
        return "Gol (Assistência: ${event['assist']})";
      }
      return "Gol (Jogada Individual)";
    }
    if (event['type'] == 'own_goal') return "Gol Contra";
    if (event['type'] == 'yellow_card') return "Cartão Amarelo";
    if (event['type'] == 'red_card') return "Cartão Vermelho";
    return "";
  }

  Widget _getEventIcon(String type) {
    if (type == 'goal') return const Icon(Icons.sports_soccer, color: Colors.greenAccent, size: 18);
    if (type == 'own_goal') return const Icon(Icons.error_outline, color: Colors.redAccent, size: 18);
    if (type == 'yellow_card') return const Icon(Icons.style, color: Colors.yellow, size: 18);
    if (type == 'red_card') return const Icon(Icons.style, color: Colors.red, size: 18);
    return const Icon(Icons.circle, color: Colors.grey, size: 10);
  }
}

class _DebugRow {
  final String label;
  final String value;
  const _DebugRow(this.label, this.value);
}

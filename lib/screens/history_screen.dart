import 'dart:convert';
import 'dart:io';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/edit_match_screen.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String historyKey = 'match_history_${widget.tournamentId}';

    if (prefs.containsKey(historyKey)) {
      setState(() {
        history = jsonDecode(prefs.getString(historyKey)!);
        // Ordena pela data mais recente
        history.sort((a, b) {
          final dateA = DateTime.parse(a['date'] ?? '1970-01-01');
          final dateB = DateTime.parse(b['date'] ?? '1970-01-01');
          return dateB.compareTo(dateA); 
        });
      });
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
    final prefs = await SharedPreferences.getInstance();
    final String historyKey = 'match_history_${widget.tournamentId}';
    await prefs.remove(historyKey);
    setState(() {
      history = [];
    });
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

                return Card(
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
                );
              },
            ),
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

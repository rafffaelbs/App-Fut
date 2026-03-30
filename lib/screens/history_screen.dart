import 'dart:convert';
import 'dart:io'; // Needed for file creation
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/edit_match_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart'; // Add this to pubspec if missing: path_provider: ^2.1.2

class HistoryScreen extends StatefulWidget {
  final String tournamentId; // We need this to load the correct history
  final String groupId; // We need this to load the correct history

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
        // Sort by date descending (newest first)
        history.sort((a, b) {
          final dateA = DateTime.parse(a['date'] ?? '1970-01-01');
          final dateB = DateTime.parse(b['date'] ?? '1970-01-01');
          return dateB.compareTo(dateA); // Descending order
        });
      });
    }
  }

  Future<void> _exportHistory() async {
    if (history.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Nada para exportar!")));
      return;
    }

    try {
      // 1. Convert Data to Pretty JSON String
      String jsonString = const JsonEncoder.withIndent('  ').convert(history);

      // 2. Create a temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/match_history_full.json');
      await file.writeAsString(jsonString);

      // 3. Share the file
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Backup Completo das Partidas');
    } catch (e) {
      print("Erro ao exportar: $e");
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
        title: const Text(
          "Acesso Restrito",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: passController,
          obscureText: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            //hintText: "Digite a senha (1234)",
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accentBlue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              // --- PASSWORD CHECK ---
              if (passController.text == "0101") {
                Navigator.pop(ctx); // Close dialog

                // Open Edit Screen and wait to see if changes were made
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

                // If result is true, reload the history to show new scores!
                if (result == true) {
                  _loadHistory();
                }
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Senha Incorreta!"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              "Entrar",
              style: TextStyle(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        iconTheme: IconThemeData(color: AppColors.textWhite),
        title: Text("Histórico", style: TextStyle(color: AppColors.textWhite)),
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
                  title: Text(
                    "Limpar Tudo?",
                    style: TextStyle(color: AppColors.textWhite),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("Cancelar"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(c);
                        _clearHistory();
                      },
                      child: const Text(
                        "Limpar",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Text(
                "Sem partidas.",
                style: TextStyle(color: Colors.white38),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final match = history[index];
                final String duration = match['match_duration'] ?? 'N/A';

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
                          icon: const Icon(
                            Icons.edit,
                            color: AppColors.accentBlue,
                            size: 20,
                          ),
                          onPressed: () => _promptPasswordForEdit(index, match),
                        ),
                        const Icon(
                          Icons.expand_more,
                          color: Colors.white54,
                        ), // Default expansion arrow
                      ],
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Barcelona ",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "${match['scoreRed']} x ${match['scoreWhite']}",
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          " Real Madrid",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                    subtitle: Center(
                      child: Text(
                        "Duração: $duration",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    children: [
                      const Divider(color: Colors.white12),
                      if (match['events'] != null &&
                          (match['events'] as List).isNotEmpty)
                        ...((match['events'] as List).map((event) {
                          return ListTile(
                            dense: true,
                            leading: _getEventIcon(event['type']),
                            title: Text(
                              "${event['player']} (${event['team']})",
                              style: TextStyle(color: AppColors.textWhite),
                            ),

                            // --- FIXED LINE BELOW ---
                            subtitle: Text(
                              _getEventDescription(
                                event,
                              ), // Calling the helper function
                              style: const TextStyle(color: Colors.white54),
                            ),

                            // ------------------------
                            trailing: Text(
                              event['time'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          );
                        }).toList())
                      else
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "Nenhum evento registrado.",
                            style: TextStyle(color: Colors.grey),
                          ),
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
      // Check if assist exists and is not null
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
    if (type == 'goal')
      return const Icon(
        Icons.sports_soccer,
        color: Colors.greenAccent,
        size: 18,
      );
    if (type == 'own_goal')
      return const Icon(Icons.error_outline, color: Colors.redAccent, size: 18);
    if (type == 'yellow_card')
      return const Icon(Icons.style, color: Colors.yellow, size: 18);
    if (type == 'red_card')
      return const Icon(Icons.style, color: Colors.red, size: 18);
    return const Icon(Icons.circle, color: Colors.grey, size: 10);
  }
}

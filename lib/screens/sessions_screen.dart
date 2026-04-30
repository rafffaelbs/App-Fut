import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'tournament_dashboard_screen.dart';

class SessionsScreen extends StatefulWidget {
  final String groupId;

  const SessionsScreen({super.key, required this.groupId});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<Map<String, dynamic>> sessions = [];
  bool isLoading = true;

  String get _storageKey => 'sessions_${widget.groupId}';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_storageKey)) {
      setState(() {
        sessions = List<Map<String, dynamic>>.from(
          jsonDecode(prefs.getString(_storageKey)!),
        );
        // Sort by date descending (newest first)
        sessions.sort((a, b) {
          final dateA = a['timestamp'] != null
              ? DateTime.parse(a['timestamp'])
              : DateTime(1970);
          final dateB = b['timestamp'] != null
              ? DateTime.parse(b['timestamp'])
              : DateTime(1970);
          return dateB.compareTo(dateA); // Descending order
        });
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(sessions));
  }

  void _showSessionDialog({int? index}) {
    final bool isEditing = index != null;
    final session = isEditing ? sessions[index] : null;

    final TextEditingController nameController = TextEditingController(
      text: isEditing ? session!['title'] : '',
    );
    final TextEditingController playersController = TextEditingController(
      text: isEditing ? session!['jogadores'].toString() : '4',
    );
    final TextEditingController timeController = TextEditingController(
      text: isEditing ? session!['duration'].toString() : '8',
    );

    bool isInfiniteLimit = isEditing ? (session!['win_limit'] == 0) : false;
    final TextEditingController winLimitController = TextEditingController(
      text: isEditing && session!['win_limit'] != null && session!['win_limit'] > 0
          ? session['win_limit'].toString()
          : '3',
    );
    bool isDraftMode = isEditing ? (session!['draft_mode'] ?? false) : false;

    // --- NEW: DATE LOGIC ---
    DateTime selectedDate = isEditing && session!['timestamp'] != null
        ? DateTime.parse(session['timestamp'])
        : DateTime.now();

    final TextEditingController dateController = TextEditingController(
      text:
          "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}",
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.headerBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        // --- NEW: StatefulBuilder allows the bottom sheet to update its own UI when a date is picked ---
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? "Editar Pelada" : "Nova Pelada / Sessão",
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Nome (ex: Pelada 12/03)",
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accentBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- NEW: DATE PICKER FIELD ---
                  TextField(
                    controller: dateController,
                    readOnly: true, // Prevents keyboard from popping up
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Data",
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accentBlue),
                      ),
                      suffixIcon: Icon(
                        Icons.calendar_month,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    onTap: () async {
                      // Open the calendar popup
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020), // Start year
                        lastDate: DateTime(2100), // End year
                        builder: (context, child) {
                          return Theme(
                            // Make the calendar dark themed to match your app
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.accentBlue,
                                onPrimary: Colors.white,
                                surface: AppColors.deepBlue,
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null) {
                        // Update the text field and variable inside the modal
                        setModalState(() {
                          selectedDate = picked;
                          dateController.text =
                              "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                        });
                      }
                    },
                  ),
                  // ------------------------------
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: playersController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Jogadores por Time",
                            labelStyle: TextStyle(color: Colors.white54),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: timeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Tempo (minutos)",
                            labelStyle: TextStyle(color: Colors.white54),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: winLimitController,
                          enabled: !isInfiniteLimit,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isInfiniteLimit ? Colors.white38 : Colors.white),
                          decoration: InputDecoration(
                            labelText: "Limite de Vitórias Seguidas",
                            labelStyle: const TextStyle(color: Colors.white54),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.accentBlue),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: isInfiniteLimit,
                            activeColor: AppColors.accentBlue,
                            onChanged: (val) {
                              setModalState(() {
                                isInfiniteLimit = val ?? false;
                              });
                            },
                          ),
                          const Text("Sem limite", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Modo Draft Toggle
                  const Text("Modo de Formação de Times", style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => isDraftMode = false),
                            child: Container(
                              decoration: BoxDecoration(
                                color: !isDraftMode ? AppColors.accentBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text("Sorteio", style: TextStyle(color: !isDraftMode ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => isDraftMode = true),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDraftMode ? AppColors.accentBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text("Draft (Capitães)", style: TextStyle(color: isDraftMode ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Preencha o nome!")),
                          );
                          return;
                        }

                        setState(() {
                          final newSessionData = {
                            'id': isEditing
                                ? session!['id']
                                : 'session_${DateTime.now().millisecondsSinceEpoch}',
                            'title': nameController.text.trim(),
                            'date': dateController.text
                                .trim(), // Visually: 12/03/2026
                            'timestamp': selectedDate
                                .toIso8601String(), // --- NEW: Raw data for filtering: 2026-03-12T00:00:00 ---
                            'status': isEditing
                                ? session!['status']
                                : 'Em Andamento',
                            'jogadores':
                                int.tryParse(playersController.text) ?? 5,
                            'duration': int.tryParse(timeController.text) ?? 8,
                            'win_limit': isInfiniteLimit ? 0 : (int.tryParse(winLimitController.text) ?? 3),
                            'draft_mode': isDraftMode,
                          };

                          if (isEditing) {
                            sessions[index] = newSessionData;
                          } else {
                            sessions.insert(0, newSessionData);
                          }
                        });

                        _saveSessions();
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        isEditing ? "SALVAR ALTERAÇÕES" : "CRIAR",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteSession(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Excluir Pelada?",
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: const Text(
          "Tem certeza que deseja excluir esta pelada?",
          style: TextStyle(color: Colors.white70),
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
            onPressed: () {
              setState(() {
                sessions.removeAt(index);
              });
              _saveSessions();
              Navigator.pop(ctx);
            },
            child: const Text(
              "Excluir",
              style: TextStyle(color: Colors.redAccent),
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
              itemBuilder: (context, index) {
                final item = sessions[index];
                final isLive = item['status'] == 'Em Andamento';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: AppColors.headerBlue,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 4,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TournamentDashboardScreen(
                              groupId: widget.groupId,
                              tournamentId: item['id'],
                              tournamentName: item['title'],
                              totalPlayers: item['jogadores'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: isLive
                              ? Border.all(
                                  color: AppColors.accentBlue,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: isLive
                                ? AppColors.accentBlue
                                : Colors.white10,
                            child: Icon(
                              Icons.sports_soccer,
                              color: isLive ? Colors.white : Colors.white38,
                            ),
                          ),
                          title: Text(
                            item['title'],
                            style: const TextStyle(
                              color: AppColors.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item['date'],
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.people,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${item['jogadores']}x${item['jogadores']}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white54,
                            ),
                            color: AppColors.headerBlue,
                            onSelected: (String value) {
                              if (value == 'edit') {
                                _showSessionDialog(index: index);
                              } else if (value == 'delete') {
                                _deleteSession(index);
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Editar',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Excluir',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentBlue,
        onPressed: () => _showSessionDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

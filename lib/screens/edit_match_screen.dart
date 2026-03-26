import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

class EditMatchScreen extends StatefulWidget {
  final String tournamentId;
  final int matchIndex;
  final Map<String, dynamic> matchData;
  final String groupId; // --- NEW: To load all group players ---

  const EditMatchScreen({
    super.key,
    required this.tournamentId,
    required this.matchIndex,
    required this.matchData,
    required this.groupId,
  });

  @override
  State<EditMatchScreen> createState() => _EditMatchScreenState();
}

class _EditMatchScreenState extends State<EditMatchScreen> {
  late int scoreRed;
  late int scoreWhite;
  late List<dynamic> events;

  List<String> allGroupPlayerNames = [];
  bool isLoadingPlayers = true;

  @override
  void initState() {
    super.initState();
    scoreRed = widget.matchData['scoreRed'] ?? 0;
    scoreWhite = widget.matchData['scoreWhite'] ?? 0;
    events = List.from(widget.matchData['events'] ?? []);

    _loadAllPlayers();
  }

  Future<void> _loadAllPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    Set<String> playerSet = {};

    // 1. Load the ENTIRE Group Roster
    final String? dbData = prefs.getString('players_${widget.groupId}');
    if (dbData != null) {
      final List<dynamic> groupPlayers = jsonDecode(dbData);
      playerSet.addAll(groupPlayers.map((p) => p['name'].toString()));
    }

    // 2. Load players who were present in this session/tournament
    final String? presentData = prefs.getString(
      'present_players_${widget.tournamentId}',
    );
    if (presentData != null) {
      final List<dynamic> presentPlayers = jsonDecode(presentData);
      playerSet.addAll(presentPlayers.map((p) => p['name'].toString()));
    }

    // 3. Fallback: Add players from the match data (just in case someone played but was later deleted from the group!)
    if (widget.matchData['players']['red'] != null) {
      playerSet.addAll(
        (widget.matchData['players']['red'] as List).map(
          (p) => p['name'].toString(),
        ),
      );
    }
    if (widget.matchData['players']['white'] != null) {
      playerSet.addAll(
        (widget.matchData['players']['white'] as List).map(
          (p) => p['name'].toString(),
        ),
      );
    }
    for (var ev in events) {
      if (ev['player'] != null) playerSet.add(ev['player']);
      if (ev['assist'] != null && ev['assist'].toString().isNotEmpty)
        playerSet.add(ev['assist']);
    }

    setState(() {
      allGroupPlayerNames = playerSet.toList()..sort();
      if (allGroupPlayerNames.isEmpty)
        allGroupPlayerNames.add("Jogador Desconhecido");
      isLoadingPlayers = false;
    });
  }

  void _deleteEvent(int index) {
    setState(() {
      final removedEvent = events.removeAt(index);
      if (removedEvent['type'] == 'goal') {
        if (removedEvent['team'] == 'Vermelho')
          scoreRed = max(0, scoreRed - 1);
        else
          scoreWhite = max(0, scoreWhite - 1);
      } else if (removedEvent['type'] == 'own_goal') {
        if (removedEvent['team'] == 'Vermelho')
          scoreWhite = max(0, scoreWhite - 1);
        else
          scoreRed = max(0, scoreRed - 1);
      }
    });
  }

  void _showEventDialog({int? index}) {
    final bool isEditing = index != null;
    final Map<String, dynamic> currentEvent = isEditing
        ? Map.from(events[index])
        : {
            'type': 'goal',
            'team': 'Vermelho',
            'player': allGroupPlayerNames.first,
            'assist': null,
            'time': '00:00',
          };

    String selectedType = currentEvent['type'];
    String selectedTeam = currentEvent['team'];

    // --- FIX FOR THE RED SCREEN CRASH ---
    // Safely verify the player exists in the list, otherwise default to the first player
    String selectedPlayer = allGroupPlayerNames.contains(currentEvent['player'])
        ? currentEvent['player']
        : allGroupPlayerNames.first;

    String? selectedAssist =
        (currentEvent['assist'] != null &&
            allGroupPlayerNames.contains(currentEvent['assist']))
        ? currentEvent['assist']
        : null;

    TextEditingController timeController = TextEditingController(
      text: currentEvent['time'],
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.headerBlue,
              title: Text(
                isEditing ? "Editar Evento" : "Novo Evento",
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: AppColors.deepBlue,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Tipo de Evento",
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'goal', child: Text("Gol")),
                        DropdownMenuItem(
                          value: 'own_goal',
                          child: Text("Gol Contra"),
                        ),
                        DropdownMenuItem(
                          value: 'yellow_card',
                          child: Text("Cartão Amarelo"),
                        ),
                        DropdownMenuItem(
                          value: 'red_card',
                          child: Text("Cartão Vermelho"),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedTeam,
                      dropdownColor: AppColors.deepBlue,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Time",
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Vermelho',
                          child: Text(
                            "Vermelho",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Branco',
                          child: Text("Branco"),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedTeam = val!),
                    ),
                    const SizedBox(height: 10),

                    // --- NOW SHOWS EVERYONE IN THE GROUP ---
                    DropdownButtonFormField<String>(
                      value: selectedPlayer,
                      dropdownColor: AppColors.deepBlue,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Jogador",
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                      items: allGroupPlayerNames
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedPlayer = val!),
                    ),
                    const SizedBox(height: 10),

                    if (selectedType == 'goal')
                      DropdownButtonFormField<String?>(
                        value: selectedAssist,
                        dropdownColor: AppColors.deepBlue,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Assistência",
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text("Sem Assistência"),
                          ),
                          ...allGroupPlayerNames
                              .where(
                                (name) => name != selectedPlayer,
                              ) // Prevent assisting yourself
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              ),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => selectedAssist = val),
                      ),

                    if (selectedType == 'goal') const SizedBox(height: 10),

                    TextField(
                      controller: timeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Tempo (MM:SS)",
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.accentBlue),
                        ),
                      ),
                    ),
                  ],
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
                  onPressed: () {
                    setState(() {
                      final newEvent = {
                        'type': selectedType,
                        'team': selectedTeam,
                        'player': selectedPlayer,
                        'assist': selectedAssist,
                        'time': timeController.text.trim().isEmpty
                            ? "00:00"
                            : timeController.text.trim(),
                      };

                      if (isEditing)
                        events[index] = newEvent;
                      else
                        events.add(newEvent);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    "Salvar Evento",
                    style: TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final String historyKey = 'match_history_${widget.tournamentId}';

    if (prefs.containsKey(historyKey)) {
      List<dynamic> history = jsonDecode(prefs.getString(historyKey)!);
      int actualIndex = (history.length - 1) - widget.matchIndex;

      history[actualIndex]['scoreRed'] = scoreRed;
      history[actualIndex]['scoreWhite'] = scoreWhite;
      history[actualIndex]['events'] = events;

      await prefs.setString(historyKey, jsonEncode(history));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Partida atualizada com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingPlayers) {
      return const Scaffold(
        backgroundColor: AppColors.deepBlue,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        title: const Text(
          "Editar Partida",
          style: TextStyle(color: AppColors.textWhite),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text(
              "SALVAR",
              style: TextStyle(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Placar Final",
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text(
                      "Vermelho",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.white,
                          ),
                          onPressed: () =>
                              setState(() => scoreRed = max(0, scoreRed - 1)),
                        ),
                        Text(
                          "$scoreRed",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(() => scoreRed++),
                        ),
                      ],
                    ),
                  ],
                ),
                const Text(
                  "X",
                  style: TextStyle(color: Colors.white54, fontSize: 24),
                ),
                Column(
                  children: [
                    const Text(
                      "Branco",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(
                            () => scoreWhite = max(0, scoreWhite - 1),
                          ),
                        ),
                        Text(
                          "$scoreWhite",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(() => scoreWhite++),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const Divider(color: Colors.white24, height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Eventos da Partida",
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    "Adicionar",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _showEventDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            events.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "Nenhum evento registrado.",
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final ev = events[index];
                      return Dismissible(
                        key: Key(ev.toString() + index.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) => _deleteEvent(index),
                        child: Card(
                          color: AppColors.headerBlue,
                          child: ListTile(
                            leading: Icon(
                              ev['type'] == 'goal'
                                  ? Icons.sports_soccer
                                  : ev['type'] == 'own_goal'
                                  ? Icons.error_outline
                                  : Icons.style,
                              color: ev['type'] == 'yellow_card'
                                  ? Colors.yellow
                                  : (ev['team'] == 'Vermelho'
                                        ? Colors.redAccent
                                        : Colors.white),
                            ),
                            title: Text(
                              "${ev['player']} (${ev['team']})",
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              _getEventDescription(ev),
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () =>
                                      _showEventDialog(index: index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _deleteEvent(index),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  String _getEventDescription(Map<String, dynamic> event) {
    if (event['type'] == 'goal') {
      if (event['assist'] != null && event['assist'].toString().isNotEmpty)
        return "Gol (Assistência: ${event['assist']})";
      return "Gol (Jogada Individual)";
    }
    if (event['type'] == 'own_goal') return "Gol Contra";
    if (event['type'] == 'yellow_card') return "Cartão Amarelo";
    if (event['type'] == 'red_card') return "Cartão Vermelho";
    return "";
  }
}

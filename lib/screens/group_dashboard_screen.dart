import 'dart:convert';
import 'dart:io';
import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/group_ranking_screen.dart';
import 'package:app_do_fut/screens/players_screen.dart';
import 'package:app_do_fut/screens/sessions_screen.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupDashboardScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDashboardScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  int _currentIndex = 0;

  Future<void> _exportGroupData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Get all sessions for this group
      final String sessionsKey = 'sessions_${widget.groupId}';
      List<dynamic> allSessions = [];
      if (prefs.containsKey(sessionsKey)) {
        allSessions = jsonDecode(prefs.getString(sessionsKey)!);
      }

      if (allSessions.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nenhuma pelada encontrada neste grupo!"))
        );
        return;
      }

      // 2. Build the combined JSON object
      Map<String, dynamic> combinedData = {
        'group_id': widget.groupId,
        'group_name': widget.groupName,
        'export_date': DateTime.now().toIso8601String(),
        'sessions_data': [],
      };

      for (var session in allSessions) {
        String sessionId = session['id'];
        String historyKey = 'match_history_$sessionId';

        List<dynamic> sessionHistory = [];
        if (prefs.containsKey(historyKey)) {
          sessionHistory = jsonDecode(prefs.getString(historyKey)!);
        }

        // Add history into the session object
        Map<String, dynamic> sessionData = Map<String, dynamic>.from(session);
        sessionData['history'] = sessionHistory;

        combinedData['sessions_data'].add(sessionData);
      }

      // 3. Convert Data to Pretty JSON String
      String jsonString = const JsonEncoder.withIndent('  ').convert(combinedData);

      // 4. Create a temporary file
      final directory = await getTemporaryDirectory();
      // Replace spaces to make file name safe
      final safeGroupName = widget.groupName.replaceAll(RegExp(r'\s+'), '_');
      final file = File('${directory.path}/historico_grupo_$safeGroupName.json');
      await file.writeAsString(jsonString);

      // 5. Share the file
      await Share.shareXFiles([XFile(file.path)], text: 'Backup Completo do Grupo: ${widget.groupName}');

    } catch (e) {
      debugPrint("Erro ao exportar grupo: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao criar arquivo de exportação."))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // These are the 3 screens we will switch between inside the Group
    final List<Widget> screens = [
      SessionsScreen(groupId: widget.groupId), // 1. Uses the new file!
      GroupRankingScreen(groupId: widget.groupId),
      PlayersScreen(groupId: widget.groupId),
    ];

    final List<String> titles = ["Peladas", "Estatísticas Gerais", "Elenco"];

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.greenAccent),
              onPressed: _exportGroupData,
              tooltip: "Exportar Dados do Grupo",
            ),
        ],
      ),

      body: screens[_currentIndex], // Shows the active tab

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.headerBlue,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "Peladas",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Ranking",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Elenco"),
        ],
      ),
    );
  }
}

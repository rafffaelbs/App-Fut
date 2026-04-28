import 'package:app_do_fut/constants/app_colors.dart';
import 'package:app_do_fut/screens/group_ranking_screen.dart';
import 'package:app_do_fut/screens/players_screen.dart';
import 'package:app_do_fut/screens/sessions_screen.dart';
import 'package:app_do_fut/screens/manage_badges_screen.dart'; // <-- IMPORTANTE
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SessionsScreen(groupId: widget.groupId), 
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // BOTAO NOVO PARA FABRICA DE TROFEUS
          IconButton(
            icon: const Icon(Icons.workspace_premium, color: Colors.amber),
            tooltip: "Gerenciar Troféus",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageBadgesScreen(groupId: widget.groupId),
                ),
              );
            },
          )
        ],
      ),

      body: screens[_currentIndex], 

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
